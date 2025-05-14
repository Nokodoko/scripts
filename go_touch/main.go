package main

import (
	"fmt"
	"os/exec"
)

func Check(statusCode int, message string) {
	var urgency string
	switch statusCode {
	case 0:
		urgency = "low"
	case 1:
		urgency = "critical"
	}

	cmd := exec.Command("notify-send", "-u", urgency, message)
	err := cmd.Run()
	if err != nil {
		fmt.Printf("Error with sending notification, %s\n", err)
	}
}
