# Where should we write the GIF?
Output forms.gif

# Set up a 1200x600 terminal with 46px font.
Set FontSize 20
Set Width 1200
Set Height 600

# Type a command in the terminal.
Type "odin run ."

# Pause for dramatic effect...
Sleep 500ms

# Run the command by pressing enter.
Enter

# Wait for form to load
Sleep 2s

# Fill in login username
Type "admin"
Sleep 500ms

# Tab to password field
Tab
Sleep 500ms

# Type password
Type "password123"
Sleep 500ms

# Tab to submit button
Tab
Sleep 500ms

# Press Enter to submit
Enter
Sleep 2s

# Switch to register form
Right
Sleep 2s

# Fill in registration fields
Type "newuser"
Sleep 500ms
Tab
Type "user@example.com"
Sleep 500ms
Tab
Type "securepass"
Sleep 500ms
Tab
Type "securepass"
Sleep 500ms

# Admire the output for a bit.
Sleep 3s
