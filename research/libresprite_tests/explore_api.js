// Check what app.launch expects
console.log("Trying app.launch...");

// Try creating a dialog to see what's available
try {
    var dialog = app.createDialog("test");
    console.log("dialog type: " + typeof dialog);
    for (var key in dialog) {
        console.log("dialog." + key);
    }
} catch(e) {
    console.log("createDialog error: " + e);
}
