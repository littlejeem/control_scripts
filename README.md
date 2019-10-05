# control_scripts
A collection of scripts that control functions, primarily on a media pc

The scripts are intended for use with UDEV and SYSTEMD

These script allow for headless ripping and processing of Audio CD's

To use navigate to a folder of your choice eg. ```/home/USER/temp``` or ```/home/USER/Downloads```.

clone the repository
```bash
git clone https://github.com/littlejeem/control_scripts.git
```

if using CD ripping services you will also need my other repository
```bash
git clone https://github.com/littlejeem/abcde_configs.git
```

move into the directory
```bash
cd /home/USER/temp
```

make the install script executable
```bash
sudo chmod +x control_scripts_install.sh
```

run the script
```bash
./control_scripts_install.sh
```
