# Touch Portal Plugin for Open Hardware Monitor
TouchPortal Plugin to Utilize Statistics from OpenHardwareMonitor

## Current Statistics Supported

```
Single CPU Total Load Percentage
Single CPU Total Status- Low, Medium, High - based on above Percentage
    Low < 45%
    Medium < 85%
    High >= 85%
    
Memory Load Percentage
Memory Load Status - Low, Medium, High - base don above Percentage
    Low < 40%
    Medium < 85%
    High >= 85%
```

## Getting Started

If you use [Touch Portal](https://touch-portal.com) and are interested in having a "dashboard" display of some base computer statistics, these instructions will help get that setup for you.

If you don't use Touch Portal - how dare you, you should!

### Prerequisites

Download and run Open Hardware Monitor - you can find it here: https://openhardwaremonitor.org/
Current tested version is 0.9.2

After download, open the OpenHardwareMonitor.exe file, for this plugin to run correctly, please enable the following "Options" menu items: //TODO Add Picture instead of text

```
Start Minimized
Minimize To Tray
Minimize On Close
Run On Windows Startup
```

### Installing


## Notes
* this has only been tested on Windows 10 Pro, your mileage my vary
* this was tested on a single CPU Desktop machine, your mileage may vary. 
* If you experience issues with the plug please submit an issue with a saved copy of your Open Hardware Monitor report (File -> Save Report), and it will be reviewed as time permits


## Built With

* [StrawberryPerl](http://strawberryperl.com/) - Coding Language
* [PAR::Packaging](https://metacpan.org/pod/pp) - EXE Packaging Utility
* [Win32::OLE](https://metacpan.org/pod/Win32::OLE) - Used to access the WMI information

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **Jameson Allen** - *Initial work* - [Spdermn02](https://github.com/spdermn02

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details

## Acknowledgments

* Thank you to Open Hardware Monitor for writing your statstics somewhere accessible
* Thank you to Ty and Reinier for creating and developing Touch Portal
