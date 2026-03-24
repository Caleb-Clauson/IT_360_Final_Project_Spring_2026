#!/bin/bash

# Basic Bash shell script template

echo "Hello, World!"

# Variables
name="User"
echo "Welcome, $name!"

# Simple conditional
if [ -n "$name" ]; then
    echo "Name is set to: $name"
else
    echo "Name is not set"
fi

# Simple loop
for i in {1..3}; do
    echo "Iteration $i"
done

echo "Script completed!"
