package main

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"path/filepath"
	"time"

	"github.com/caicloud/log-pilot/pilot/configurer"
	"github.com/caicloud/log-pilot/pilot/configurer/filebeat"
	"github.com/caicloud/log-pilot/pilot/discovery"
	"github.com/caicloud/log-pilot/pilot/log"
)

var (
	template      = flag.String("path.template", "", "Template file path for filebeat")
	filebeatHome  = flag.String("path.filebeat-home", "", "Filebeat home path")
	base          = flag.String("path.base", "/", "Directory which mount host path")
	logPath       = flag.String("path.logs", "", "Logs path")
	logPrefix     = flag.String("logPrefix", "caicloud", "Log prefix of the env parameters. Multiple prefixes should be separated by \",\"")
	logLevel      = flag.String("logLevel", "info", "Log level: debug, info, warning, error, critical")
	logMaxBytes   = flag.Uint("log.maxSize", 10*1024*1024, "Max size of log file in bytes")
	logMaxBackups = flag.Uint("log.maxBackups", 7, "Max backups of log files")
	logToStderr   = flag.Bool("e", false, "Log to stderr")
)

func main() {
	flag.Parse()

	log.Config(*logLevel, *logPath, *logToStderr, *logMaxBytes, *logMaxBackups)

	baseDir, err := filepath.Abs(*base)
	if err != nil {
		log.Fatal("invalid path.base:", err)
	}

	var cfgr configurer.Configurer

	cfgr, err = filebeat.New(baseDir, *template, *filebeatHome)
	if err != nil {
		log.Fatalf("error create configurer: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		c := make(chan os.Signal, 1)
		signal.Notify(c, os.Interrupt)
		// Wait for Interrupt signal
		<-c
		log.Info("Received signal and shutdown")
		// Gracefully shutdown
		cancel()
		time.Sleep(2 * time.Second)
		os.Exit(0)
	}()

	d, err := discovery.New(baseDir, *logPrefix, cfgr)
	if err := d.Start(ctx); err != nil {
		log.Fatal(err)
	}
}
