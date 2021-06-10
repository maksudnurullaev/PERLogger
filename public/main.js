
const { Splitpanes, Pane } = splitpanes;

var app = new Vue({
    el: '#app',
    data: {
        vueVersion: Vue.version,
        l1_servers: [],                   // Level#1 servers
        l1_selected: [],                  // Level#1 selected servers
        l2_servers: new Map(),
        l2_selected: [],
        l2_forceRerenderKey: 0,
        l2_last_data: new Map(),
        l3_logs: [],
        l3_mouseover_id: "",
        disableMainBtnShowLog: true,
        disableMainBtnSelAll: false,
        disableMainBtnSelNone: true,
        disableMainBtnSelRev: true,
    },
    methods: {
        overLogText: function (elId) {
            if (this.getL2SelectedLFilesCount() <= 1) {
                return;
            }
            document.getElementById(elId).classList.add("show-text");
        },
        leaveLogText: function (elId) {
            if (this.getL2SelectedLFilesCount() <= 1) {
                return;
            }
            document.getElementById(elId).classList.remove("show-text");
        },
        l2_forceRerender: function () {
            this.l2_forceRerenderKey += 1;
        },
        log2HTML: function (log) {
            var result = log.log.replace(/(?:\r\n|\r|\n)/g, '<br />');
            result += `<hr /><small>${log.ltime} | ${shrink_me(file_name_from_path(log.lfile),20)}</small>`;
            return result;
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
                    this.l2_reset();
            }
            if (_selected.length == 0) { this.l2_reset(); }
            this.l1_selected = _selected;
        },
        l2_reset: function () {
            this.l2_servers = new Map();
            this.l2_selected = [];
        },
        jsonRefreshServers: function () {
            var self = this;
            axios.get('/servers/').then(
                function (response) {
                    self.l1_servers = [];
                    response.data.map(function (el) {
                        self.l1_servers.push({
                            value: el.lhost,
                            lhost_md5: el.lhost_md5,
                            html: el.lhost + "<sup>" + el.count + "</sup>",
                        });
                    });
                }
            );
        },
        getL2SelectedLFilesCount: function () {
            var result = 0;
            app.l2_servers.forEach((lfiles, server) => {
                result = lfiles.length;
            });
            return result;
        },
        jsonGetLogs: function () {
            var data = {};
            app.l2_servers.forEach((lfiles, server) => {
                data[this.l1_getMD5ForHost(server)] = lfiles;
            });
            axios.post('/logs/', data).then(
                function (response) {
                    app.l3_logs = response.data;
                }
            );
        },
        jsonGetServerLFiles: function (server, server_data) {
            axios.get('/serverlfiles/', {
                params: {
                    server: server,
                },
            }).then(
                function (response) {
                    server_data.push(response.data);
                }
            );
        },
        l1_getMD5ForHost: function (lhost) {
            for (const el of app.l1_servers) {
                if (el.value == lhost) {
                    return el.lhost_md5;
                }
            }
        },
        l3_getLogFilesForServer: function (sname) {
            if (app.l2_servers.size == 0) return [];
            return Array.from(app.l2_servers.get(sname));
        },
        l2_updateServerAndFiles: function (server, files) {
            if (files && files.length > 0) this.l2_servers.set(server, files);
            else this.l2_servers.delete(server);

            //TODO: may be we should change this code for more effective version to update l2_selected
            this.l2_selected = Array.from(this.l2_servers.keys());
        },
        l2_refreshData: function (oldValues) {
            if (app.l1_selected.length == 0) {
                this.l2_reset();
                return;
            }

            if (oldValues && oldValues.length > 0) {
                oldValues.map(function (server) {
                    app.l2_servers.delete(server);
                });
            }
            app.l2_selected = Array.from(this.l2_servers.keys());
        },
    },
    components: { Splitpanes, Pane },
    watch: {
        l1_selected: function (values, oldValues) {
            l1_refreshMainButtons();
            if (values.length < oldValues.length) {
                this.l2_refreshData(arr_diff(values, oldValues));
                l2_last_data.clear();
            }
        },
    },
    beforeMount() {
        this.jsonRefreshServers()
    },
});

function l1_refreshMainButtons() {
    if (app.l1_servers.length == 0) { return; }
    // Main Btn - Show Log
    if (app.l1_selected.length == 0) {
        app.disableMainBtnShowLog = true;
    } else {
        app.disableMainBtnShowLog = false;
    }
    // Main Btn - Select All
    if (app.l1_selected.length == app.l1_servers.length) {
        app.disableMainBtnSelAll = true;
    } else {
        app.disableMainBtnSelAll = false;
    }
    // Main Btn - Select None
    if (app.l1_selected.length == 0) {
        app.disableMainBtnSelNone = true;
    } else {
        app.disableMainBtnSelNone = false;
    }
    // Main Btn - Reverse selection
    if (app.l1_selected.length == 0 ||
        app.l1_selected.length == app.l1_servers.length) {
        app.disableMainBtnSelRev = true;
    } else {
        app.disableMainBtnSelRev = false;
    }
};

function arr_diff(a1, a2) {

    var a = [], diff = [];

    for (var i = 0; i < a1.length; i++) {
        a[a1[i]] = true;
    }

    for (var i = 0; i < a2.length; i++) {
        if (a[a2[i]]) {
            delete a[a2[i]];
        } else {
            a[a2[i]] = true;
        }
    }

    for (var k in a) {
        diff.push(k);
    }

    return diff;
}

function blink_me(elId, _times) {
    if (_times) {
        setTimeout(() => {
            document.getElementById(elId).classList.toggle("blink");
            blink_me(elId, --_times);
        }, 500);
    } else {
        document.getElementById(elId).classList.remove("blink");
    }
}

var re = /[^\/]+$/;
function file_name_from_path(path) {
    return path.match(re)[0];
}

var re2 = /^(.{7})(.*)(.{10})$/;
function shrink_me(s, count) {
    if (s.length > 20) {
        var reg2Result = re2.exec(s);
        s = reg2Result[1] + '...' + reg2Result[3];
    }
    return s;
}