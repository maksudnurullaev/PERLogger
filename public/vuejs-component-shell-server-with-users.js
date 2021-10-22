Vue.component('shell-server-with-users', {
  props: ['server'],
  data: function () {
    return {
      total_files: 0,
      selected: [],
      options: [],
      server_data: [],
      allSelected: false,
      indeterminate: false
    }
  },
  methods: {
    toggleAll(checked) {
      this.selected = [];
      if (checked) {
        for (const [key, value] of Object.entries(this.server.users)) {
          this.selected.push(key);
        }
      }
    },
    formatOptions: function () {
      this.options = [];
      for (const [key, value] of Object.entries(this.server.users)) {
        this.options.push({ text: value.user, value: key });
      }
    },
  },
  watch: {
    selected(newValue, oldValue) {
      if (newValue.length === 0) {
        this.indeterminate = false
        this.allSelected = false
      } else if (newValue.length === Object.keys(this.server.users).length) {
        this.indeterminate = false
        this.allSelected = true
      } else {
        this.indeterminate = true
        this.allSelected = false
      }
    },
  },
  beforeMount() {
    this.formatOptions();
  },
  template: `
<div style="margin-bottom: 10px;">
  <b-form-group>
    <template #label>
        <b-form-checkbox
          v-model="allSelected"
          :indeterminate="indeterminate"
          aria-describedby="logfiles"
          aria-controls="logfiles"
          @change="toggleAll"
          >
          <b>{{ server.nameOrIP }}:</b>
        </b-form-checkbox>
    </template>
  </b-form-group>
      <b-form-checkbox-group
        :id="server.id"
        v-model="selected"
        :options="options"
        name="user"
        class="ml-4"
        style="margin-bottom: 5px;"
        aria-label="Individual server user"
        stacked
      ></b-form-checkbox-group>

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
