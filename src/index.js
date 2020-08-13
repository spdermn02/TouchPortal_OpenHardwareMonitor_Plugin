const TPClient = new (require("touchportal-api")).Client;
const wmi = require('node-wmi');

const pluginId = "TPOpenHardwareMonitor";

const namespace = 'root\\OpenHardwareMonitor';
const updateInterval = 2000;

wmi.Query({namespace,class:'Hardware'},function(err,hardware){
console.log(hardware);
});

const updateHardwareInfo = () => {
    console.log('here');
};

TPClient.on("Action",(action) => {

});

TPClient.on("Info", (info) => {
    console.log(info);

    setInterval(updateHardwareInfo,updateInterval);
});

TPClient.connect({ pluginId });