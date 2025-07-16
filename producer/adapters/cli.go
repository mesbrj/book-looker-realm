package adapters

import (
	"fmt"
	"os"
)

// CLIAdapter handles command line arguments
type CLIAdapter struct{}

// NewCLIAdapter creates a new CLI adapter
func NewCLIAdapter() *CLIAdapter {
	return &CLIAdapter{}
}

// ParseArgs parses command line arguments to get the PDF file path
func (c *CLIAdapter) ParseArgs() (string, error) {
	args := os.Args[1:]

	if len(args) == 0 {
		return "", fmt.Errorf("usage: %s <pdf_file_path>", os.Args[0])
	}

	if len(args) > 1 {
		return "", fmt.Errorf("too many arguments. usage: %s <pdf_file_path>", os.Args[0])
	}

	return args[0], nil
}
