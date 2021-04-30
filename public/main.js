
const { Splitpanes, Pane } = splitpanes;

var app = new Vue({
    el: '#app',
    data: {
        counter: 0,
        stopit: false,
        message: 'Hello Vue.js!',
        servers: [],
        selected: [],
        disableMainBtnShowLog: true,
        disableMainBtnSelAll: false,
        disableMainBtnSelNone: true,
        disableMainBtnSelRev: true,
    },
    methods: {
        vueVersion: function () {
            return Vue.version;
        },
        selectAll: function (smode) {
            smode = smode.toLowerCase();
            // check smode as ENUM
            if (!['all', 'none', 'reverse'].includes(smode)) {
                try {
                    throw new TypeError("Wrong SMODE parameter passed to selectAll!");
                } catch (e) {
                    console.error(e.message);
                    return;
                }
            }
            var _selected = [];
            switch (smode) {
                case 'all':
                    this.servers.forEach(function (server) {
                        _selected.push(server.value);
                    });
                    break;
                case 'reverse':
                    this.servers.forEach(function (server) {
                        if (!app.selected.includes(server.value)) {
                            _selected.push(server.value);
                        };
                    });
            }
            this.selected = _selected;
        },
        refreshServers: function () {
            var self = this;
            axios.get('/servers/').then(
                function (response) {
                    self.servers = [];
                    response.data.map(function (el) {
                        self.servers.push({
                            value: el.lhost,
                            html: el.lhost + "<sup>" + el.count + "</sup>",
                        });
                    });
                }
            );
        },
    },
    components: { Splitpanes, Pane },
    watch: {
        selected: function (value, oldValue) {
            refreshMainButtons();
        },
    },
    beforeMount() {
        this.refreshServers()
    },
});

function refreshMainButtons() {
    if( app.servers.length == 0 ) { return; }
    // Main Btn - Show Log
    if( app.selected.length == 0 ) {
        app.disableMainBtnShowLog = true;
    } else {
        app.disableMainBtnShowLog = false;
    }
    // Main Btn - Select All
    if( app.selected.length == app.servers.length ) {
        app.disableMainBtnSelAll = true;
    } else {
        app.disableMainBtnSelAll = false;
    }
    // Main Btn - Select None
    if( app.selected.length == 0 ) {
        app.disableMainBtnSelNone = true;
    } else {
        app.disableMainBtnSelNone = false;
    }
    // Main Btn - Reverse selection
    if( app.selected.length == 0 ||
        app.selected.length == app.servers.length ) {
        app.disableMainBtnSelRev = true;
    } else {
        app.disableMainBtnSelRev = false;
    }
};