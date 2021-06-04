Vue.component('server-with-log-files', {
  props: ['server'],
  data: function () {
    return {
      total_files: 0,
      selected: [],
      server_data: [],
      allSelected: false,
      indeterminate: false
    }
  },
  methods: {
    toggleAll(checked) {
      this.selected = [];
      if (checked) {
        for (const [key, value] of Object.entries(this.server_data[0])) {
          this.selected = this.selected.concat(value.map((el) => { return el.value; }));
        }
      }
    },
    userDef(user) {
      return "User: " + user;
    },
    getOptions(v) {
      var result = [];
      var re = /[^\/]+$/;
      var re2 = /^(.{7})(.*)(.{10})$/;
      v.map((el) => {
        var key = el.lfile.match(re)[0];
        if (key.length > 20) {
          var reg2Result = re2.exec(key);
          key = reg2Result[1] + '...' + reg2Result[3];
        }
        if (app.l2_last_data.has(el.di)) {
          if (app.l2_last_data.get(el.di) != el.count) {
            //setTimeout(() => {
              blink_me(el.di, 10);
            //}, 1 * 300);
          }
        }
        app.l2_last_data.set(el.di, el.count);

        result.push({ value: el.lfile_md5, html: `<span id="${el.di}" title="${el.lfile}">${key}<sup>${el.count}</sup></span>` });
      });
      return result;
    },
  },
  watch: {
    selected(newValue, oldValue) {
      // Handle changes in individual flavour checkboxes
      if (newValue.length === 0) {
        this.indeterminate = false
        this.allSelected = false
      } else if (newValue.length === this.total_files) {
        this.indeterminate = false
        this.allSelected = true
      } else {
        this.indeterminate = true
        this.allSelected = false
      }
      app.l2_updateServerAndFiles(this.server, this.selected);
    },
    server_data(newValue, oldValue) {
      this.total_files = 0;
      if (newValue.length == 1) {
        for (const [key, value] of Object.entries(newValue[0])) {
          newValue[0][key] = this.getOptions(value);
          this.total_files += value.length;
        }
      } else {
        this.options_data = {};
      }
    }
  },
  beforeMount() {
    app.jsonGetServerLFiles(this.server, this.server_data);
  },
  template: `
<div>
  <b-form-group>
    <template #label>
        <b-form-checkbox
          v-model="allSelected"
          :indeterminate="indeterminate"
          aria-describedby="logfiles"
          aria-controls="logfiles"
          @change="toggleAll"
          >
          <b>{{ server }}:</b>
        </b-form-checkbox>
    </template>
  </b-form-group>
  <template v-for="(v,k) in server_data[0]">
      <div class="user_group">{{ userDef(k) }}</div>
      <b-form-checkbox-group
        :id="k"
        v-model="selected"
        :options="v"
        name="logfiles"
        class="ml-4"
        aria-label="Individual server log files"
        stacked
      ></b-form-checkbox-group>
  </template>
  <!--
  <div>
    Selected: <strong>{{ selected }}</strong><br>
    All Selected: <strong>{{ allSelected }}</strong><br>
    Indeterminate: <strong>{{ indeterminate }}</strong>
  </div>
  -->  
</div>
`
});
