package main

import (
	"github.com/gin-gonic/gin"
	"os"
	"fmt"
	"log"
	"flag"
	"strings"
)

func main(){
	var version = "0.0.1"
	var showVersion bool
	var tftp_dir string
	var kshost string

	flag.BoolVar(&showVersion, "v", false, "show version")
	flag.BoolVar(&showVersion, "version", false, "show version")
	flag.StringVar(&tftp_dir, "d", "/var/lib/tftpboot/", "tftp directory path")
	flag.StringVar(&tftp_dir, "directory", "/var/lib/tftpboot/", "tftp directory path")
	flag.StringVar(&kshost, "h", "", "kickstart host")
	flag.StringVar(&kshost, "host", "", "kickstart host")

	flag.Parse()

	if showVersion {
		fmt.Println("version:", version)
		return
	}
	fmt.Println("tftp direcotry:", tftp_dir)

	if kshost == "" {
		log.Fatalln("Specify kickstart hostname or IPaddress")
	}

	if _, err := os.Stat(tftp_dir + `pxelinux.cfg`); os.IsNotExist(err) {
		if err := os.Mkdir(tftp_dir + `pxelinux.cfg`, 0755); err != nil {
			log.Fatalln(err)
		}
	}

	r := gin.Default()
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "ping",
		})
	})

	type sv struct {
		Mac	string	`json:"mac"`
		Ip	string	`json:"ip"`
		Host	string	`json:"host"`
	}

	r.POST("/pxe", func(c *gin.Context) {
		var s sv
		c.BindJSON(&s)

		fmt.Println(s)
		file, err := os.Create(tftp_dir + `pxelinux.cfg/01-` + s.Mac)
		if err != nil {
			log.Fatalln("file Open Error")
		}
		defer file.Close()



		output := `default menu.c32
PROMPT 0
TIMEOUT 100
ONTIMEOUT local

menu title ######## PXE Boot Menu ##########

default local

LABEL local
        LOCALBOOT -1

LABEL linux
		menu label ^1)Install system CentOS 7 x64 with local Repository
		kernel images/centos7/vmlinuz
		append initrd=images/centos7/initrd.img ip=dhcp ks=http://_HOST_/ks/centos7_dhstd.ks text
`

		output = strings.Replace(output, "_HOST_", kshost, 1)
		file.Write(([]byte)(output))
	})

	r.Run()
}
