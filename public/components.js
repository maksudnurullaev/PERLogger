Vue.component('server-with-log-files', {
    props: ['server'],
    data: function () {
      return {
        logfiles: [],
        selected: [],
        allSelected: false,
        indeterminate: false
      }
    },
    methods: {
      toggleAll(checked) {
        this.selected = checked ? this.logfiles.slice() : [];
      }
    },
    watch: {
      selected(newValue, oldValue) {
        // Handle changes in individual flavour checkboxes
        if (newValue.length === 0) {
          this.indeterminate = false
          this.allSelected = false
        } else if (newValue.length === this.logfiles.length) {
          this.indeterminate = false
          this.allSelected = true
        } else {
          this.indeterminate = true
          this.allSelected = false
        }
        app.l2_updateServerAndFiles(this.server, this.selected);
      }
    },
    beforeMount() {
        app.jsonGetServerLFiles(this.server, this.logfiles);
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
      <template v-slot="{ ariaDescribedby }">
          <b-form-checkbox-group
            :id="server"
            v-model="selected"
            :options="logfiles"
            :aria-describedby="ariaDescribedby"
            name="logfiles"
            class="ml-4"
            aria-label="Individual server log files"
            stacked
            ></b-form-checkbox-group>
      </template>
    </b-form-group>
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
