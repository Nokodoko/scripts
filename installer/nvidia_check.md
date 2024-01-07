It seems like the NVIDIA kernel module is not being loaded properly. Here are a few steps you can try to troubleshoot the issue:

1. Make sure you have the correct NVIDIA driver installed for your graphics card. You can check the official NVIDIA website for the latest driver version compatible with your card.

2. Verify that the `nvidia` module is available in the `/lib/modules/$(uname -r)/kernel/drivers/video/` directory. If it is not present, it might indicate an issue with the installation or configuration of the NVIDIA driver.

3. Check if the `nvidia` module is blacklisted. Open the `/etc/modprobe.d/` directory and look for any files containing `nvidia` in their names. If you find any, remove or comment out the lines that blacklist the `nvidia` module.

4. Ensure that the `nvidia` module is included in the initramfs. Run the following command to regenerate the initramfs:

   ```
   sudo mkinitcpio -P
   ```

   This command will rebuild the initramfs with the necessary modules included.

5. Reboot your system and check if the `nvidia` module is loaded using the `lsmod` command. If it still doesn't appear, try loading it manually with `sudo modprobe nvidia` and check for any error messages.

If the issue persists, it might be helpful to provide more information about your system configuration, such as the Linux distribution and version, the graphics card model, and any relevant error messages you encounter.
