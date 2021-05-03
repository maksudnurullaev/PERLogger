
const { Splitpanes, Pane } = splitpanes;

var app = new Vue({
    el: '#app',
    data: {
        counter: 0,
        stopit: false,
        message: 'Hello Vue.js!',
        l1_servers: [],  // Level#1 servers
        l1_selected: [], // Level#1 selected servers
        l2_servers_and_files: new Map(),
        disableMainBtnShowLog: true,
        disableMainBtnSelAll: false,
        disableMainBtnSelNone: true,
        disableMainBtnSelRev: true,
    },
    methods: {
        vueVersion: function () {
            return Vue.version;
        },
        l1_selection: function (smode) {
            smode = smode.toLowerCase();
            // check smode as ENUM
            if (!['all', 'none', 'reverse'].includes(smode)) {
                try {
                    throw new TypeError("Wrong SMODE parameter passed to l1_selection!");
                } catch (e) {
                    console.error(e.message);
                    return;
                }
            }
            var _selected = [];
            switch (smode) {
                case 'all':
                    this.l1_servers.forEach(function (server) {
                        _selected.push(server.value);
                    });
                    break;
                case 'reverse':
                    this.l1_servers.forEach(function (server) {
                        if (!app.l1_selected.includes(server.value)) {
                            _selected.push(server.value);
                        };
                    });
            }
            this.l1_selected = _selected;
        },
        jsonRefreshServers: function () {
            var self = this;
            axios.get('/servers/').then(
                function (response) {
                    self.l1_servers = [];
                    response.data.map(function (el) {
                        self.l1_servers.push({
                            value: el.lhost,
                            html: el.lhost + "<sup>" + el.count + "</sup>",
                        });
                    });
                }
            );
        },
        updateServerAndFiles: function(server, files){
            if (files && files.length > 0) this.l2_servers_and_files.set(server, files);
            else this.l2_servers_and_files.delete(server);
        },
    },
    components: { Splitpanes, Pane },
    watch: {
        l1_selected: function (value, oldValue) {
            refreshMainButtons();
        },
    },
    beforeMount() {
        this.jsonRefreshServers()
    },
});

function refreshMainButtons() {
    if( app.l1_servers.length == 0 ) { return; }
    // Main Btn - Show Log
    if( app.l1_selected.length == 0 ) {
        app.disableMainBtnShowLog = true;
    } else {
        app.disableMainBtnShowLog = false;
    }
    // Main Btn - Select All
    if( app.l1_selected.length == app.l1_servers.length ) {
        app.disableMainBtnSelAll = true;
    } else {
        app.disableMainBtnSelAll = false;
    }
    // Main Btn - Select None
    if( app.l1_selected.length == 0 ) {
        app.disableMainBtnSelNone = true;
    } else {
        app.disableMainBtnSelNone = false;
    }
    // Main Btn - Reverse selection
    if( app.l1_selected.length == 0 ||
        app.l1_selected.length == app.l1_servers.length ) {
        app.disableMainBtnSelRev = true;
    } else {
        app.disableMainBtnSelRev = false;
    }
};