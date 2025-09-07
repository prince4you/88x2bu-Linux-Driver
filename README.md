# 88x2bu-Linux-Driver
88x2bu Linux Driver Installer

https://img.shields.io/badge/License-MIT-blue.svg https://img.shields.io/badge/Platform-Linux-green.svg https://img.shields.io/badge/Maintained-Yes-success.svg https://img.shields.io/badge/Shell_Script-100%25-brightgreen.svg

Professional one-click installer for Realtek rtl88x2bu WiFi drivers on Linux systems.

✨ Features

· 🚀 One-Command Installation - Fully automated setup process
· 🔄 DKMS Integration - Automatic driver recompilation on kernel updates
· 📊 Comprehensive Logging - Detailed installation logs at /var/log/88x2bu-installer.log
· ⚡ Secure Boot Aware - Detects and warns about Secure Boot configuration
· 🔧 Auto-Dependency Resolution - Installs all required build tools automatically
· 💾 Backup System - Creates restore points before making changes

🚀 Quick Start

Automated Installation

```bash
# Single command installation (recommended)
curl -sSL https://raw.githubusercontent.com/prince4you/88x2bu-Linux-Driver/main/setup.sh | sudo bash
```

Manual Installation

```bash
# Download, make executable, and run
wget -q https://raw.githubusercontent.com/prince4you/88x2bu-Linux-Driver/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

📋 Supported Devices

This driver supports WiFi adapters with Realtek rtl88x2bu chipset including:

Device Model Chipset Interface
TP-Link Archer T3U rtl88x2bu USB 3.0
TP-Link Archer T4U rtl88x2bu USB 3.0
D-Link DWA-181 rtl88x2bu USB 3.0
EDUP EP-AC1605 rtl88x2bu USB 3.0
USB-AC53 NANO rtl88x2bu USB 3.0

🛠️ System Requirements

· Kernel: Linux 4.4+ (5.10+ recommended)
· Distros: Ubuntu, Debian, Linux Mint, Pop!_OS, Fedora, Arch Linux
· Tools: git, build-essential, dkms, linux-headers
· Architecture: x86_64, arm64, armv7l

📖 Usage Examples

```bash
# Install with debug output
sudo DEBUG=true ./setup.sh

# Check driver status after installation
lsmod | grep 88x2bu

# View connection information
iwconfig

# Check installation logs
tail -f /var/log/88x2bu-installer.log
```

🧹 Maintenance

Update Driver

```bash
# Simply re-run the installer - it will update automatically
sudo ./setup.sh
```

Uninstall Driver

```bash
# Navigate to driver directory and uninstall
cd ~/88x2bu-20210702
sudo make uninstall
sudo dkms remove 88x2bu/1.0 --all

# Or use the included uninstall script (if available)
sudo ./uninstall.sh
```

🐛 Troubleshooting

Common Issues & Solutions

1. Driver not loading after reboot
   ```bash
   sudo modprobe 88x2bu
   ```
2. Secure Boot preventing loading
   · Disable Secure Boot in BIOS/UEFI settings
   · Or sign the driver for your system
3. Kernel update broke driver
   ```bash
   # Re-run installer to rebuild for new kernel
   sudo ./setup.sh
   ```
4. WiFi not showing up
   ```bash
   # Check hardware detection
   lsusb | grep -i realtek
   
   # Reload driver
   sudo rmmod 88x2bu
   sudo modprobe 88x2bu
   ```

📊 Verification

Verify successful installation with these commands:

```bash
# Check driver is loaded
lsmod | grep 88x2bu

# Verify kernel recognition
dmesg | grep -i 88x2bu

# Check network interface
ip link show

# View driver information
modinfo 88x2bu
```

🤝 Contributing

We welcome contributions! Please feel free to:

1. Fork the repository
2. Create a feature branch (git checkout -b feature/amazing-feature)
3. Commit your changes (git commit -m 'Add amazing feature')
4. Push to the branch (git push origin feature/amazing-feature)
5. Open a Pull Request

📝 Changelog

v2.0.0 (2024-01-20)

· Complete rewrite with enterprise-grade error handling
· Added DKMS support for automatic kernel updates
· Enhanced logging system
· Secure Boot detection and warnings
· Backup and restore functionality

v1.0.0 (2023-11-15)

· Initial release
· Basic driver compilation and installation
· Dependency automation

👤 Maintainer

Sunil (@prince4you)

· GitHub: https://github.com/prince4you
· Repository: 88x2bu-Linux-Driver

📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

⚠️ Disclaimer

This software is provided as-is without any warranty. Use at your own risk. The maintainers are not responsible for any system instability or damage caused by this software.

---

<div align="center">

Need Help? Create an issue on GitHub

Making Linux WiFi work seamlessly ✨

</div>
