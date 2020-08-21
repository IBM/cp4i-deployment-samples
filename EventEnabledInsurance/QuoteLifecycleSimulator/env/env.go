package env

import (
	"log"
	"os"
	"strconv"
)

var osExit = os.Exit

func GetEnvString(key string) string {
	val, ok := os.LookupEnv(key)
	if !ok {
		log.Printf("%s env var not set", key)
		osExit(1)
	}
	return val
}

func GetEnvInt(key string) int64 {
	str := GetEnvString(key)
	val, err := strconv.ParseInt(str, 0, 32)
	if err != nil {
		log.Printf("Failed to convert '%s' to an int: %v", str, err)
		osExit(1)
	}
	return val
}
