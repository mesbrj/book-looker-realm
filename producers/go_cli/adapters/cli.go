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

// ParseArgs parses command line arguments to get the PDF file paths and output path
func (c *CLIAdapter) ParseArgs() (string, string, error) {
	args := os.Args[1:]

	if len(args) == 0 {
		return "", "", fmt.Errorf("usage: %s <pdf_file_paths> <output_path>", os.Args[0])
	}

	if len(args) == 1 {
		return "", "", fmt.Errorf("missing output path. usage: %s <pdf_file_paths> <output_path>", os.Args[0])
	}

	if len(args) > 2 {
		return "", "", fmt.Errorf("too many arguments. usage: %s <pdf_file_paths> <output_path>", os.Args[0])
	}

	return args[0], args[1], nil
}
