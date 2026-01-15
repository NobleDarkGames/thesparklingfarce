console.log("Opening base tile...");
var sprite = app.open("/home/homeuser/dev/sparklingfarce/research/libresprite_tests/base_tile.png");

console.log("=== Sprite properties ===");
for (var key in sprite) {
    var val = sprite[key];
    var type = typeof val;
    if (type === 'function') {
        console.log("sprite." + key + "()");
    } else {
        console.log("sprite." + key + " = " + val + " (" + type + ")");
    }
}

sprite.close();
