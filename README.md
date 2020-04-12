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

Location of where it is downloaded and run from do not matter, as long as it is runnign and writing sensor data it can run from anywhere on the computer.

After download, run the OpenHardwareMonitor.exe file, for this plugin to run correctly, please enable the following "Options" menu items:

![OHM Options](images/ohm_options.png)

### Installing

* Grab the OpenHardwareMonitor.tpp file from the github repo. This is a package of the entire Touch Portal Plugin including the executable
* Open your Touch Portal application
* Import the plugin by using the Wrench icon.
  ![Touch Portal Plugin Import](images/touchPortalImportPlugin.png)
** Navigate the file browser to find the downloaded OpenHardwareMonitor.tpp file
** Select it and click 'Open' button
  ![Touch Portal Plugin Import File Browse](images/tpp_file_selector.png)
* When it is done importing you should see this popup
  

## Sensors and Values Available



## Notes

- this has only been tested on Windows 10 Pro, your mileage my vary
- this was tested on a single CPU Desktop machine, your mileage may vary.
- If you experience issues with the plug please submit an issue with a saved copy of your Open Hardware Monitor report (File -> Save Report), and it will be reviewed as time permits

## Built With

- [StrawberryPerl](http://strawberryperl.com/) - Coding Language
- [PAR::Packaging](https://metacpan.org/pod/pp) - EXE Packaging Utility
- [Win32::OLE](https://metacpan.org/pod/Win32::OLE) - Used to access the WMI information

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags).

## Authors

- **Jameson Allen** - _Initial work_ - [Spdermn02](https://github.com/spdermn02

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details

## Acknowledgments

- Thank you to Open Hardware Monitor for writing your statstics somewhere accessible
- Thank you to Ty and Reinier for creating and developing Touch Portal
