Vue.component('server-with-log-files', {
    props: ['server'],
    data: function () {
      return {
        sfiles: ['Orange', 'Grape', 'Apple', 'Lime', 'Very Berry'],
        selected: [],
        allSelected: false,
        indeterminate: false
      }
    },
    methods: {
      toggleAll(checked) {
        this.selected = checked ? this.sfiles.slice() : [];
      }
    },
    watch: {
      selected(newValue, oldValue) {
        // Handle changes in individual flavour checkboxes
        if (newValue.length === 0) {
          this.indeterminate = false
          this.allSelected = false
        } else if (newValue.length === this.sfiles.length) {
          this.indeterminate = false
          this.allSelected = true
        } else {
          this.indeterminate = true
          this.allSelected = false
        }
        app.l2_updateServerAndFiles(this.server, this.selected);
      }
    },
    template: `
<div>
    <b-form-group>
       <template #label>
          <b>{{ server }}:</b><br>
          <b-form-checkbox
             v-model="allSelected"
             :indeterminate="indeterminate"
             aria-describedby="sfiles"
             aria-controls="sfiles"
             @change="toggleAll"
             >
             {{ allSelected ? 'Un-select All' : 'Select All' }}
          </b-form-checkbox>
       </template>
       <template v-slot="{ ariaDescribedby }">
          <b-form-checkbox-group
             :id="server"
             v-model="selected"
             :options="sfiles"
             :aria-describedby="ariaDescribedby"
             name="sfiles"
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
