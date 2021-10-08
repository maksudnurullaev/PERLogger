
const { Splitpanes, Pane } = splitpanes;

var app = new Vue({
    el: '#app',
    data: {
        vueVersion: Vue.version,
        currentActivePage: "help",
        logs: {
            config: {
                selected: '_new_',
                selected_text: null,
                options: [{ value: '_new_', text: 'New' }],
                error_defs: "error",
                warning_defs: "warning",
            },
            configs: null,
            top: {
                selected: 20,
                options: [20, 50, 100, 200, 500, 1000],
            },
            all: 0,
            errors: 0,
            warnings: 0,
            show: {
                errors: false,
                warnings: false,
            },
        },
        user: {
            name: '',
            nameState: null,
            password: '',
            passwordState: null,
            loginStatus: "",
            logged: false,
            roles: [],
            MSADUser: false,
        },
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
        userHasRole: function (role) {
            if (this.user.roles.length == 0) {
                return false;
            }
            return this.user.roles.indexOf(role) != -1;
        },
        try2Login: function (bvModalEvt) {
            // Prevent modal from closing
            bvModalEvt.preventDefault();
            // Trigger submit handler
            this.try2LoginSubmit();
        },
        try2LoginSubmit: function () {
            if (this.user.MSADUser) {
                window.location.href = "/user/msad"
                return
            }
            if (this.checkLoginFormValidity()) {
                this.jsonLogin()
            }
        },
        dummyFunction: function() { },
        checkLoginFormValidity: function () {
            this.user.nameState = this.$refs.loginForm.elements['name-input'].validity.valid
            this.user.passwordState = this.$refs.loginForm.elements['password-input'].validity.valid
            if (this.user.nameState && this.user.passwordState) {
                this.user.nameState = null
                this.user.passwordState = null
                return true
            }
            return false
        },
        overLogText: function (elId) {
            if (this.getL2SelectedLFilesCount() <= 1) {
                return;
            }
            var fileLogEl = document.getElementById(elId);
            if (fileLogEl) fileLogEl.classList.add("show-text");
        },
        leaveLogText: function (elId) {
            if (this.getL2SelectedLFilesCount() <= 1) {
                return;
            }
            var fileLogEl = document.getElementById(elId);
            if (fileLogEl) fileLogEl.classList.remove("show-text");
        },
        jsonSaveLogConfig: function () {
            var data = {
                warning_defs: app.logs.config.warning_defs,
                error_defs: app.logs.config.error_defs,
            };
            if (app.logs.config.selected != '_new_') {
                data.id = app.logs.config.selected;
            } else {
                data.name = app.logs.config.selected_text;
            }
            axios.post('/logs/config/save', data).then(
                function (response) {
                    if (response.data.status == 0) {
                        app.jsonGetLogConfigs(response.data.id);
                    } else {
                        app.try2CatchBadResponse(response.data);
                    }
                }
            );
        },
        jsonDeleteLogConfig: function () {
            var data = {
                id: app.logs.config.selected,
            };
            axios.post('/logs/config/del', data).then(
                function (response) {
                    if (response.data.status == 0) {
                        app.jsonGetLogConfigs();
                    } else {
                        app.try2CatchBadResponse(response.data);
                    }
                }
            );
        },
        updateLogsL3LogsToolbar: function () {
            app.$nextTick(() => {
                var logs = document.querySelector("#L3_LOGS");
                if (logs) {
                    app.logs.errors = logs.querySelectorAll(".alert-danger").length;
                    app.logs.warnings = logs.querySelectorAll(".alert-warning").length;
                    app.logs.all = app.logs.errors + app.logs.warnings;
                } else {
                    app.logs.all = 0;
                    app.logs.errors = 0;
                    app.logs.warnings = 0;
                }
            })
        },
        updateLogConfig: function () {
            if (app.logs.config.selected != '_new_') {
                app.logs.config.error_defs = app.logs.configs[app.logs.config.selected].error_defs;
                app.logs.config.warning_defs = app.logs.configs[app.logs.config.selected].warning_defs;
            } else {
                app.logs.config.selected_text = "";
                app.logs.config.error_defs = "error";
                app.logs.config.warning_defs = "warning";
            }
            app.updateLogsL3LogsToolbar();
        },
        jsonGetLogConfigs: function (id) {
            axios.get('/logs/configs').then(
                function (response) {
                    app.logs.config.options = [{ value: '_new_', text: 'New' }];
                    if (response.data.status == 0) {
                        Object.keys(response.data.configs).forEach(key => {
                            app.logs.config.options.push({
                                value: key,
                                text: response.data.configs[key].name,
                            });
                        });
                        app.logs.configs = response.data.configs;
                        if (id) {
                            app.logs.config.selected = id;
                        } else {
                            app.logs.config.selected = "_new_";
                        }
                    } else {
                        app.try2CatchBadResponse(response.data);
                        app.logs.config.selected = "_new_";
                    }
                    app.updateLogConfig();
                }
            );
        },
        l2_forceRerender: function () {
            this.l2_forceRerenderKey += 1;
        },
        log2HTML: function (log) {
            var result = log.log.replace(/(?:\r\n|\r|\n)/g, '<br />');
            result += `<hr /><small>${log.ltime} | ${shrink_me(file_name_from_path(log.lfile), 20)}</small>`;
            return result;
        },
        checkLogAlertVariant: function (logText) { // TODO: find more optimized version of this search
            // danger
            var words = app.logs.config.error_defs.trim();
            if (words.length) {
                var wordsArray = words.split(/[\s+|\n]/);
                var wordsRe = new RegExp(wordsArray.join("|"), "gi");
                if (wordsRe.test(logText)) return "danger";
            }
            // warning
            words = app.logs.config.warning_defs.trim();
            if (words.length) {
                wordsArray = words.split(/[\s+|\n]/);
                wordsRe = new RegExp(wordsArray.join("|"), "gi");
                if (wordsRe.test(logText)) return "warning";
            }
            return "success";
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
        jsonGetErrWarnDefs: function () {
            //TODO
        },
        try2CatchBadResponse: function (response) {
            var msg = "Status: ";
            if (response.status) {
                msg += response.status;
            }
            if (response.error_msg) {
                if (msg.length > 0) {
                    msg += "\n";
                }
                msg += response.error_msg;
            }
            console.error(msg);
        },
        jsonRefreshServers: function () {
            var self = this;
            axios.get('/logs/servers').then(
                function (response) {
                    self.l1_servers = [];
                    if (response.data.status == 0) {
                        response.data.servers.map(function (el) {
                            self.l1_servers.push({
                                value: el.lhost,
                                lhost_md5: el.lhost_md5,
                                html: el.lhost + "<sup>" + el.count + "</sup>",
                            });
                        });
                    } else {
                        self.try2CatchBadResponse(response.data);
                    }
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
        resetModalLogin: function () {
            if (!this.user.logged) {
                this.user.name = ''
                this.user.roles = []
            }
            this.user.nameState = null
            this.user.password = ''
            this.user.passwordState = null
            this.user.loginStatus = ''
        },
        jsonLogout: function () {
            axios.get('/user/logout').then(
                function (response) {
                    if (response.data.status == 0) { // OK
                        app.user.logged = false
                        app.resetModalLogin()
                        app.currentActivePage = 'help'
                    } else {
                        app.try2CatchBadResponse(response.data);
                    }
                }
            );
        },
        jsonCheckCurrentUser: function () {
            axios.get('/user/current').then(
                function (response) {
                    if (response.data.status == 0) { // OK
                        app.user.name = response.data.user;
                        app.user.logged = true;
                        app.user.roles = response.data.roles;
                        app.jsonGetLogConfigs();
                        app.quickPageAccess();
                    } else {
                        app.try2CatchBadResponse(response.data);
                    }
                }
            );
        },
        quickPageAccess: function () {
            //TODO: just for quick access to main page in development stage, could be removed later
            app.currentActivePage = app.user.roles.indexOf("shell_operator") != -1 ? 'shell' : 'help'
        },
        jsonLogin: function () {
            var data = { MSADUser: (this.user.MSADUser ? 1 : 0) };

            if (!this.user.MSADUser) {
                data['user.name'] = this.user.name;
                data['user.password'] = this.user.password;
            }

            axios.post('/user/login', data).then(
                function (response) {
                    if (response.data.status == 0) { // OK
                        app.user.logged = true;
                        app.user.roles = response.data.roles;
                        app.resetModalLogin();
                        app.$nextTick(() => {
                            app.$bvModal.hide('modal-login')
                        });
                        app.user.lastLoginTime = new Date();
                        app.quickPageAccess();
                    } else { // FAILED
                        app.user.nameState = false;
                        app.user.passwordState = false;
                        app.user.loginStatus = response.data.error_msg;
                    }
                }
            );
        },
        jsonGetLogs: function () {
            var data = {};
            data['where'] = [];
            app.l2_servers.forEach((lfiles, server) => {
                data['where'].push({
                    lhost_md5: app.l1_getMD5ForHost(server),
                    lfile_md5: lfiles
                });
            });
            data['top'] = app.logs.top.selected;
            axios.post('/logs/get', data).then(
                function (response) {
                    if (response.data.status == 0) {
                        app.l3_logs = response.data.logs;
                        app.updateLogsL3LogsToolbar();
                    } else {
                        app.try2CatchBadResponse(response.data);
                    }
                }
            );
        },
        showWarningLogs: function () {

        },
        jsonGetServerLFiles: function (server, server_data) {
            axios.get('/logs/serverlfiles', {
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
        showLogs: function () {
            var logs = document.querySelector("#L3_LOGS");
            if (!this.logs.show.errors && !this.logs.show.warnings) {
                // show all
                if (this.logs.all) {
                    for (const el of logs.querySelectorAll(".alert")) {
                        el.style.display = "";
                    }
                }
            } else {
                if (this.logs.all) {
                    for (const el of logs.querySelectorAll(".alert")) {
                        el.style.display = "none";
                    }
                }
                if (this.logs.errors) {
                    for (const el of logs.querySelectorAll(".alert-danger")) {
                        el.style.display = this.logs.show.errors ? "" : "none";
                    }
                }
                if (this.logs.warnings) {
                    for (const el of logs.querySelectorAll(".alert-warning")) {
                        el.style.display = this.logs.show.warnings ? "" : "none";
                    }
                }
            }
        },
    },
    components: { Splitpanes, Pane },
    watch: {
        l1_selected: function (values, oldValues) {
            l1_refreshMainButtons();
            if (values.length < oldValues.length) {
                this.l2_refreshData(arr_diff(values, oldValues));
                this.l2_last_data.clear();
            }
        },
        currentActivePage: function (value, oldValue) {
            if (value != oldValue) {
                this.l1_selected = []
                this.l2_selected = []
                this.l3_logs = []
            }
        },
    },
    beforeMount() {
        this.jsonCheckCurrentUser();
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
