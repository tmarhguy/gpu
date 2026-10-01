# Upload-demo fragment shader: flat magenta, no texture or lighting.
# Proves runtime UART programming - this program never passes through
# synthesis; it arrives over the serial line after the bitstream is loaded.
LDI r4.x, 1.0
LDI r4.y, 0.1
LDI r4.z, 0.9
OUT 0, r4
END
