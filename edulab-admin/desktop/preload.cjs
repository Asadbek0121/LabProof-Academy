const { contextBridge } = require("electron");

contextBridge.exposeInMainWorld("labproofAdmin", {
  platform: process.platform,
});
