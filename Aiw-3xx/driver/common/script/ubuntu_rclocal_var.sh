#!/bin/bash

# Merging existing rc.local content with new content

# Save original rc.local content into a variable
original_content=$(cat /etc/rc.local)

# New content to be added
new_content="\n# New command to run on startup\necho 'Hello, World!' >> /etc/rc.local"

# Combine original and new content
merged_content="$original_content$new_content"

# Write the combined content back to rc.local

# Ensure rc.local is executable
chmod +x /etc/rc.local

echo "$merged_content" > /etc/rc.local
