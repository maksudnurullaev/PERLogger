
const { Splitpanes, Pane } = splitpanes;

var app = new Vue({
    el: '#app',
    data: {
        vueVersion: Vue.version,
        currentMainActivePage: "help",
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
            l1_servers: [],
            l1_servers_selected: [],
            l2_servers: new Map(),
            l2_servers_selected: [],
            l2_forceRerenderKey: 0,
            l2_last_data: new Map(),
            l3_logs: [],
            disableMainBtnShowLog: true,
            disableMainBtnSelAll: false,
            disableMainBtnSelNone: true,
            disableMainBtnSelRev: true,
        },
        shells: {
            l1_servers: [],
            l1_servers_selected: [],
            l3_programs: [],
            l3_programs_selected: [],
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
        forms: {
            server: {
                nameOrIp: '',
                description: '',
                userName: '',
                userPassword: '',
                btnPingBkgnd: '',
                btnPingSshBkgnd: '',
                overlay: false,
                mode: 'default',
                _current: null,
            },
            program: {
                data: {
                    name: "",
                    commands: "",
                    description: "",
                    id: "",
                },
                overlay: false,
            },
        },
        FormsServerMode: {
            default: 'default',
            editServer: 'editServer',
            addUser: 'addUser',
            editUser: 'editUser',
        },
    },
    methods: {
        // FormsServerMode validators
        isFSMDefault: function () { return this.forms.server.mode == this.FormsServerMode.default },
        isFSMEditServer: function () { return this.forms.server.mode == this.FormsServerMode.editServer },
        isFSMEditUser: function () { return this.forms.server.mode == this.FormsServerMode.editUser },
        isFSMAddUser: function () { return this.forms.server.mode == this.FormsServerMode.addUser },
        userHasRole: function (role) {
            if (this.user.roles.length == 0) {
                return false;
            }
            return this.user.roles.indexOf(role) != -1;
        },
        text2Html: function (textString) {
            return textString ? marked(textString) : "No description";
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
        dummyFunction: function () { },
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
                    app.jsonGetLogConfigs(response.data.id);
                }
            );
        },
        jsonDeleteLogConfig: function () {
            var data = {
                id: app.logs.config.selected,
            };
            axios.post('/logs/config/del', data).then(
                function (response) {
                    app.jsonGetLogConfigs();
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
                        app.makeToast("danger", response.data.msg);
                        app.logs.config.selected = "_new_";
                    }
                    app.updateLogConfig();
                }
            );
        },
        l2_forceRerender: function () {
            this.logs.l2_forceRerenderKey += 1;
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
                    this.logs.l1_servers.forEach(function (server) {
                        _selected.push(server.value);
                    });
                    break;
                case 'reverse':
                    this.logs.l1_servers.forEach(function (server) {
                        if (!app.logs.l1_servers_selected.includes(server.value)) {
                            _selected.push(server.value);
                        };
                    });
                    this.l2_reset();
            }
            if (_selected.length == 0) { this.l2_reset(); }
            this.logs.l1_servers_selected = _selected;
        },
        l2_reset: function () {
            this.logs.l2_servers = new Map();
            this.logs.l2_servers_selected = [];
        },
        jsonRefreshShellCommands: function () {
            axios.get('/program/all').then(
                function (response) {
                    app.shells.l3_programs = [];
                    if (response.data.status == 0) {
                        Object.keys(response.data.commands).forEach(key => {
                            app.shells.l3_programs.push({
                                value: key,
                                text: response.data.commands[key].name,
                            });
                        });
                    } else {
                        if (response.data.msg) {
                            app.makeToast("danger", response.data.msg);
                        }
                    }
                }
            );

        },
        jsonRefreshLogServers: function () {
            axios.get('/logs/servers').then(
                function (response) {
                    app.logs.l1_servers = [];
                    if (response.data.status == 0) {
                        response.data.servers.map(function (el) {
                            app.logs.l1_servers.push({
                                value: el.lhost,
                                lhost_md5: el.lhost_md5,
                                html: el.lhost + "<sup>" + el.count + "</sup>",
                            });
                        });
                    } else {
                        if (response.data.msg) {
                            app.makeToast("danger", response.data.msg);
                        }
                    }
                }
            );
        },
        getL2SelectedLFilesCount: function () {
            var result = 0;
            app.logs.l2_servers.forEach((lfiles, server) => {
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
                    app.user.logged = false
                    app.resetModalLogin()
                    app.currentMainActivePage = 'help'
                    if (response.data.msg) {
                        app.makeToast("success", response.data.msg);
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
                        app.makeToast("danger", response.data.msg);
                    }
                }
            );
        },
        quickPageAccess: function () {
            //TODO: just for quick access to main page in development stage, could be removed later
            app.currentMainActivePage = app.user.roles.indexOf("shell_operator") != -1 ? 'shell' : 'help'
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
                        if (response.data.msg) {
                            app.makeToast("danger", response.data.msg);
                        }
                    }
                }
            );
        },
        jsonGetLogs: function () {
            var data = {};
            data['where'] = [];
            app.logs.l2_servers.forEach((lfiles, server) => {
                data['where'].push({
                    lhost_md5: app.l1_getMD5ForHost(server),
                    lfile_md5: lfiles
                });
            });
            data['top'] = app.logs.top.selected;
            axios.post('/logs/get', data).then(
                function (response) {
                    if (response.data.status == 0) {
                        app.logs.l3_logs = response.data.logs;
                        app.updateLogsL3LogsToolbar();
                    } else {
                        if (response.data.msg) {
                            app.makeToast("danger", response.data.msg);
                        }
                    }
                }
            );
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
        jsonTaskPing: function (taskTimeout) {
            var data = {};
            data['taskTimeout'] = taskTimeout;
            data['nameOrIp'] = this.forms.server.nameOrIp.trim();
            axios.post('/tasks/ping', data).then(
                function (response) {
                    app.forms.server.btnPingBkgnd = (response.data.status == 0 ? "success" : "");
                    if (response.data.msg) {
                        app.makeToast((response.data.status == 0 ? "success" : "danger"), response.data.msg);
                    }
                }
            );
        },
        jsonTaskSSHLoginTest: function () {
            var data = {};
            data['nameOrIp'] = this.forms.server.nameOrIp.trim();
            data['userName'] = this.forms.server.userName.trim();
            data['userPassword'] = this.forms.server.userPassword.trim();
            app.forms.server.overlay = true;
            axios.post('/tasks/pingSsh', data).then(
                function (response) {
                    app.forms.server.btnPingSshBkgnd = (response.data.status == 0 ? "success" : "");
                    if (response.data.msg) {
                        app.makeToast((response.data.status == 0 ? "success" : "danger"), response.data.msg);
                    }
                    app.forms.server.overlay = false;
                }
            );
        },
        makeData2AddUser4Server: function () {
            var result = {
                link: '/tasks/saveUser4Server',
                data: {
                    userName: this.forms.server.userName.trim(),
                    userPassword: this.forms.server.userPassword.trim(),
                }
            }
            if (this.forms.server._current) {
                result.data['_sid'] = this.forms.server._current.id;
            }
            return result;
        },
        makeData2AddServer: function () {
            var result = {
                link: '/tasks/saveServer',
                data: {
                    nameOrIp: this.forms.server.nameOrIp.trim(),
                    description: this.forms.server.description.trim(),
                }
            }
            if (this.forms.server._current) {
                result.data['id'] = this.forms.server._current.id;
            }
            if (this.isFSMDefault()) {
                if (this.forms.server.userName.trim()) {
                    result.data['userName'] = this.forms.server.userName.trim();
                }
                if (this.forms.server.userPassword.trim()) {
                    result.data['userPassword'] = this.forms.server.userPassword.trim();
                }
            }
            return result;
        },
        jsonProgramSave: function (bvModalEvt) {
            bvModalEvt.preventDefault();

            axios.post('/program/save', this.forms.program.data).then(
                function (response) {
                    if (response.data.status == 0) {
                        app.$nextTick(() => {
                            app.$bvModal.hide('modal-program-info')
                            //app.jsonRefreshShellServers()
                        });
                    }
                    if (response.data.msg) {
                        app.makeToast((response.data.status == 0 ? "success" : "danger"), response.data.msg);
                    }
                }
            );
        },
        jsonServerInfoSave: function (bvModalEvt) {
            bvModalEvt.preventDefault();

            var result;
            if (this.isFSMDefault() || this.isFSMEditServer()) {
                result = this.makeData2AddServer();
            } else if (this.isFSMAddUser() || this.isFSMEditUser()) {
                result = this.makeData2AddUser4Server();
            } else {
                app.makeToast("danger", 'Other cases not implemented yet!');
                return;
            }
            axios.post(result.link, result.data).then(
                function (response) {
                    if (response.data.status == 0) {
                        app.$nextTick(() => {
                            app.$bvModal.hide('modal-server-info')
                            app.jsonRefreshShellServers()
                        });
                    }
                    if (response.data.msg) {
                        app.makeToast((response.data.status == 0 ? "success" : "danger"), response.data.msg);
                    }
                }
            );
        },
        jsonRefreshShellServers: function () {
            var self = this;
            axios.get('/shells/servers').then(
                function (response) {
                    app.shells.l1_servers = [];
                    if (response.data.status == 0) {
                        app.shells.l1_servers = response.data.servers;
                        app.makeToast("success", "Updated successfully!");
                    } else {
                        if (response.data.msg) {
                            app.makeToast("danger", response.data.msg);
                        }
                    }
                }
            );
        },
        try2AddUser4Sever: function (server) {
            if (server) {
                this.forms.server._current = server
                this.forms.server.mode = this.FormsServerMode.addUser
                this.forms.server.nameOrIp = this.forms.server._current.nameOrIp ? this.forms.server._current.nameOrIp : ""
                this.forms.server.description = this.forms.server._current.description ? this.forms.server._current.description : ""
                this.forms.server.userName = ""
                this.forms.server.userPassword = ""
            }
        },
        try2EditSeverInfo: function (server) {
            if (server) {
                this.forms.server._current = server
                this.forms.server.mode = this.FormsServerMode.editServer
                this.forms.server.nameOrIp = server.nameOrIp
                this.forms.server.description = server.description ? this.forms.server._current.description : ""
            }
        },
        setupModal4Server2All: function () {
            if (this.forms.server._current) {
                this.forms.server.mode = this.FormsServerMode.default
                this.forms.server.nameOrIp = ""
                this.forms.server.description = ""
                this.forms.server._current = null
                this.forms.server.userName = ""
                this.forms.server.userPassword = ""
            }
        },
        makeToast: function (tVariant, tContent) {
            this.$bvToast.toast(tContent, {
                title: tVariant.toUpperCase(),
                variant: tVariant,
                solid: true
            });
        },
        l1_getMD5ForHost: function (lhost) {
            for (const el of app.logs.l1_servers) {
                if (el.value == lhost) {
                    return el.lhost_md5;
                }
            }
        },
        l3_getLogFilesForServer: function (sname) {
            if (app.logs.l2_servers.size == 0) return [];
            return Array.from(app.logs.l2_servers.get(sname));
        },
        l2_updateServerAndFiles: function (server, files) {
            if (files && files.length > 0) this.logs.l2_servers.set(server, files);
            else this.logs.l2_servers.delete(server);

            //TODO: may be we should change this code for more effective version to update l2_selected
            this.logs.l2_servers_selected = Array.from(this.logs.l2_servers.keys());
        },
        l2_refreshData: function (oldValues) {
            if (app.logs.l1_servers_selected.length == 0) {
                this.l2_reset();
                return;
            }

            if (oldValues && oldValues.length > 0) {
                oldValues.map(function (server) {
                    app.logs.l2_servers.delete(server);
                });
            }
            app.logs.l2_servers_selected = Array.from(this.logs.l2_servers.keys());
        },
        try2DeleteSeverInfo: function (sid) {
            if (!confirm("Do you really want to delete server?")) { return; }

            var data = {
                server: sid,
            };
            axios.post('/tasks/delServer', data).then(
                function (response) {
                    if (response.data.status == 0) {
                        app.$nextTick(() => {
                            app.jsonRefreshShellServers()
                        });
                    }
                    if (response.data.msg) {
                        app.makeToast((response.data.status == 0 ? "success" : "danger"), response.data.msg);
                    }
                }
            );
        },
        try2DelUsers4Server: function (sid, uids) {
            if (!confirm("Do you really want to delete " + uids.length + " user(s)?")) { return; }

            var data = {
                server: sid,
                users: uids,
            };
            axios.post('/tasks/delUsers', data).then(
                function (response) {
                    if (response.data.status == 0) {
                        app.$nextTick(() => {
                            uids = [];
                            app.jsonRefreshShellServers()
                        });
                    }
                    if (response.data.msg) {
                        app.makeToast((response.data.status == 0 ? "success" : "danger"), response.data.msg);
                    }
                }
            );
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
        'logs.l1_servers_selected': function (values, oldValues) {
            l1_refreshMainButtons();
            if (values.length < oldValues.length) {
                this.l2_refreshData(arr_diff(values, oldValues));
                this.logs.l2_last_data.clear();
                this.logs.l3_logs.clear();
            }
        },
    },
    beforeMount() {
        this.jsonCheckCurrentUser();
    },
});

function l1_refreshMainButtons() {
    if (app.logs.l1_servers.length == 0) { return; }
    // Main Btn - Show Log
    if (app.logs.l1_servers_selected.length == 0) {
        app.logs.disableMainBtnShowLog = true;
    } else {
        app.logs.disableMainBtnShowLog = false;
    }
    // Main Btn - Select All
    if (app.logs.l1_servers_selected.length == app.logs.l1_servers.length) {
        app.logs.disableMainBtnSelAll = true;
    } else {
        app.logs.disableMainBtnSelAll = false;
    }
    // Main Btn - Select None
    if (app.logs.l1_servers_selected.length == 0) {
        app.logs.disableMainBtnSelNone = true;
    } else {
        app.logs.disableMainBtnSelNone = false;
    }
    // Main Btn - Reverse selection
    if (app.logs.l1_servers_selected.length == 0 ||
        app.logs.l1_servers_selected.length == app.logs.l1_servers.length) {
        app.logs.disableMainBtnSelRev = true;
    } else {
        app.logs.disableMainBtnSelRev = false;
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
