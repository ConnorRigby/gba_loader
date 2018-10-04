#include <stdlib.h> 
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>

#define TRANSFER_BUFFER_LEN 4

static int spi;

// This is for BBP
static const char *device = "/dev/spidev1.0";

// This is for RPI
// static const char *device = "/dev/spidev0.0";

static uint8_t TRANSFER_BUFFER[TRANSFER_BUFFER_LEN];

static uint8_t TRANSFER_MODE = 3;
static uint8_t TRANSFER_BPW = 8;
static uint32_t TRANSFER_SPEED_HZ = 100000;
static uint16_t TRANSFER_DELAY_USEC = 10000;

static void pabort(const char *s)
{
	perror(s);
	abort();
}

int SPI32Init();
uint32_t WriteSPI32NoDebug(uint32_t w);
uint32_t WriteSPI32(uint32_t w, char* msg);
void WaitSPI32(uint32_t w, uint32_t comp, char* msg);

int main(int argc, char const *argv[]);

uint32_t WriteSPI32NoDebug(uint32_t w)
{   
    TRANSFER_BUFFER[3] = (w & 0x000000ff);
    TRANSFER_BUFFER[2] = (w & 0x0000ff00) >>  8;
    TRANSFER_BUFFER[1] = (w & 0x00ff0000) >> 16;
    TRANSFER_BUFFER[0] = (w & 0xff000000) >> 24;
	struct spi_ioc_transfer tr = {
		.tx_buf = (unsigned long)TRANSFER_BUFFER,
		.rx_buf = (unsigned long)TRANSFER_BUFFER,
		.len = TRANSFER_BUFFER_LEN,
		.delay_usecs = TRANSFER_DELAY_USEC,
		.speed_hz = TRANSFER_SPEED_HZ,
		.bits_per_word = TRANSFER_BPW,
	};

	int ret = ioctl(spi, SPI_IOC_MESSAGE(1), &tr);
	if (ret < 1)
		pabort("can't send spi message");

    uint32_t r = 0;

    r += TRANSFER_BUFFER[0] << 24;
    r += TRANSFER_BUFFER[1] << 16;
    r += TRANSFER_BUFFER[2] <<  8;
    r += TRANSFER_BUFFER[3];

    return r;
}

uint32_t WriteSPI32(uint32_t w, char* msg)
{
    uint32_t r = WriteSPI32NoDebug(w);

    fprintf(stderr, "0x%08x 0x%08x  ; %s\r\n", r, w, msg);
    return  r;
}

void WaitSPI32(uint32_t w, uint32_t comp, char* msg)
{
    fprintf(stderr, "%s 0x%08x\r\n", msg, comp);
    uint32_t r;

    do
    {
        r = WriteSPI32NoDebug(w);
        usleep(10000);

    } while(r != comp);
}

int SPI32Init()
{
    int fd = open(device, O_RDWR);
	if (fd < 0)
		pabort("can't open device");

	/*
	 * spi mode
	 */
	int ret = ioctl(fd, SPI_IOC_WR_MODE, &TRANSFER_MODE);
	if (ret == -1)
		pabort("can't set spi mode");

	ret = ioctl(fd, SPI_IOC_RD_MODE, &TRANSFER_MODE);
	if (ret == -1)
		pabort("can't get spi mode");

	/*
	 * bits per word
	 */
	ret = ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &TRANSFER_BPW);
	if (ret == -1)
		pabort("can't set bits per word");

	ret = ioctl(fd, SPI_IOC_RD_BITS_PER_WORD, &TRANSFER_BPW);
	if (ret == -1)
		pabort("can't get bits per word");

	/*
	 * max speed hz
	 */
	ret = ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &TRANSFER_SPEED_HZ);
	if (ret == -1)
		pabort("can't set max speed hz");

	ret = ioctl(fd, SPI_IOC_RD_MAX_SPEED_HZ, &TRANSFER_SPEED_HZ);
	if (ret == -1)
		pabort("can't get max speed hz");
    spi = fd;
    return ret;
}

int main(int argc, char const *argv[])
{
    if(argc != 2) {
        return -1;
    }
    FILE *fp = fopen(argv[1], "rb");
    if(fp == NULL)
    {
        fprintf(stderr, "Err: Can't open file\r\n");
        return -1;
    }

    fseek(fp, 0L, SEEK_END);
    long fsize = (ftell(fp) + 0x0f) & 0xfffffff0;

    if(fsize > 0x40000)
    {
        fprintf(stderr, "Err: Max file size 256kB\r\n");
        return -1;
    }
    fprintf(stderr, "fsize: 0x%08lx\r\n", fsize);

    fseek(fp, 0L, SEEK_SET);
    long fcnt = 0;

    uint32_t r, w, w2;
    uint32_t i, bit;

    SPI32Init();

    WaitSPI32(0x00006202, 0x72026202, "Looking for GBA");

    r = WriteSPI32(0x00006202, "Found GBA");
    r = WriteSPI32(0x00006102, "Recognition OK");

    fprintf(stderr, "Send Header(NoDebug)\r\n");
    for(i=0; i<=0x5f; i++)
    {
        w = getc(fp);
        w = getc(fp) << 8 | w;
        fcnt += 2;

        r = WriteSPI32NoDebug(w);
    }

    r = WriteSPI32(0x00006200, "Transfer of header data complete");
    r = WriteSPI32(0x00006202, "Exchange master/slave info again");

    r = WriteSPI32(0x000063d1, "Send palette data");
    r = WriteSPI32(0x000063d1, "Send palette data, receive 0x73hh****");

    uint32_t m = ((r & 0x00ff0000) >>  8) + 0xffff00d1;
    uint32_t h = ((r & 0x00ff0000) >> 16) + 0xf;

    r = WriteSPI32((((r >> 16) + 0xf) & 0xff) | 0x00006400, "Send handshake data");
    r = WriteSPI32((fsize - 0x190) / 4, "Send length info, receive seed 0x**cc****");

    uint32_t f = (((r & 0x00ff0000) >> 8) + h) | 0xffff0000;
    uint32_t c = 0x0000c387;


    fprintf(stderr, "Send encrypted data(NoDebug)\r\n");

    while(fcnt < fsize)
    {
        w = getc(fp);
        w = getc(fp) <<  8 | w;
        w = getc(fp) << 16 | w;
        w = getc(fp) << 24 | w;

        w2 = w;

        for(bit=0; bit<32; bit++)
        {
            if((c ^ w) & 0x01)
            {
                c = (c >> 1) ^ 0x0000c37b;
            }
            else
            {
                c = c >> 1;
            }

            w = w >> 1;
        }
        // fprintf(stderr, "c: 0x%08x\r\nm: 0x%08x\r\nfcnt: 0x%08lx \r\n fsize: 0x%08lx\r\n", c, m, fcnt, fsize);
        m = (0x6f646573 * m) + 1;
        WriteSPI32NoDebug(w2 ^ ((~(0x02000000 + fcnt)) + 1) ^m ^0x43202f2f);

        fcnt = fcnt + 4;
    }
    fclose(fp);

    for(bit=0; bit<32; bit++)
    {
        if((c ^ f) & 0x01)
        {
            c =( c >> 1) ^ 0x0000c37b;
        }
        else
        {
            c = c >> 1;
        }

        f = f >> 1;
    }

    WaitSPI32(0x00000065, 0x00750065, "Wait for GBA to respond with CRC");

    r = WriteSPI32(0x00000066, "GBA ready with CRC");
    r = WriteSPI32(c,          "Let's exchange CRC!");

    fprintf(stderr, "CRC ...hope they match!\r\n");
    fprintf(stderr, "MulitBoot done\r\n");
    return 0;
}
