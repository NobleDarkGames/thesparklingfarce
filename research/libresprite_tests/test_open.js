console.log("Opening base tile...");
var result = app.open("/home/homeuser/dev/sparklingfarce/research/libresprite_tests/base_tile.png");
console.log("open result type: " + typeof result);
console.log("open result: " + result);

if (result) {
    for (var key in result) {
        console.log("result." + key + ": " + typeof result[key]);
    }
}
