#!/usr/bin/env perl
use Mojolicious::Lite -signatures;


get '/' => sub ($c) {
  $c->render(template => 'index');
};


app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title '###';

<div id="app">
<div id="range" class="demo">
  <span v-for="n in 20"> {{ ' ' + n }} </span>
</div>
  Counter: {{ counter }}
  <p v-bind:title="generateTit"> Vue.JS {{ version }} </p>  
  <p>{{ message }}</p>
  <p> Is active: {{ isActive }} </p>
  <button :disabled="isActive" @click="reverseMessage">Reverse Message</button>&nbsp;
  <button @click="stopcounter">{{ stopit ? "Start" : "Stop" }}</button>
  <hr />
  <input v-model="message" />
  
  <span v-if="seen" v-bind:title="generateTitle"><hr />Now you see me</span>
  <hr />
  <ol>
    <li v-for="todo in todos">
      {{ todo.text }}
    </li>
  </ol>
  <hr />
    <ol>
    <!--
      Now we provide each todo-item with the todo object
      it's representing, so that its content can be dynamic.
      We also need to provide each component with a "key",
      which will be explained later.
    -->
    <todo-item
      v-for="item in groceryList"
      v-bind:todo="item"
      v-bind:key="item.id"
    ></todo-item>
  </ol>
  
  <hr />
  <p>
   Ask a yes/no question:
   <input v-model="question" />
  </p>
  <p>{{ answer }} <img :src="imgSrc" /></p>
  <hr />
  
<ul v-for="numbers in sets">
  <li v-for="n in even(numbers)" :key="n">{{ n }}</li>
</ul>  

</div>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
<!-- Add this to <head> -->

<!-- Load required Bootstrap and BootstrapVue CSS -->
<link type="text/css" rel="stylesheet" href="//unpkg.com/bootstrap/dist/css/bootstrap.min.css" />
<link type="text/css" rel="stylesheet" href="//unpkg.com/bootstrap-vue@latest/dist/bootstrap-vue.min.css" />

<!-- Load polyfills to support older browsers -->
<script src="//polyfill.io/v3/polyfill.min.js?features=es2015%2CIntersectionObserver" crossorigin="anonymous"></script>

<!-- Load Vue followed by BootstrapVue -->
<script src="//unpkg.com/vue@latest/dist/vue.min.js"></script>
<!-- script src="https://unpkg.com/vue@3.0.6"></script -->
<script src="//unpkg.com/bootstrap-vue@latest/dist/bootstrap-vue.min.js"></script>

<!-- Load the following for BootstrapVueIcons support -->
<script src="//unpkg.com/bootstrap-vue@latest/dist/bootstrap-vue-icons.min.js"></script>
  
  <script src="https://cdn.jsdelivr.net/npm/axios@0.12.0/dist/axios.min.js"></script>
  <body><%= content %></body>

%= javascript begin

Vue.component('todo-item', {
  props: ['todo'],
  template: '<li v-bind:id="\'my-list-\' + todo.id">{{ todo.text }}</li>'
})

//const app = Vue.createApp(Counter)
var app = new Vue({
  el: '#app',
  data: {
            counter: 0,
            stopit: false,
            message: 'Hello Vue.js!',
            seen: true,
            imgSrc: "https://via.placeholder.com/150",
            generateTit: "No value!",
            version: Vue.version,
            todos: [
                { text: 'Learn JavaScript' },
                { text: 'Learn Vue' },
                { text: 'Build something awesome' }
            ],
            groceryList: [
                { id: 0, text: 'Vegetables' },
                { id: 1, text: 'Cheese' },
                { id: 2, text: 'Whatever else humans are supposed to eat' }
            ],
            question: 'Enter quiestion here...',
            answer: 'Questions usually contain a question mark. ;-)',
            sets: [[ 1, 2, 3, 4, 5 ], [6, 7, 8, 9, 10]]
    },
    computed: {
        generateTitle(){
            return "This message generated at: " + Date.now()
        },
        isActive(){
            return this.message.length%2?false:true
        }
    },
    methods: {
        reverseMessage() {
            this.message = this.message
                .split('')
                .reverse()
                .join('');
            this.seen = !this.seen;
        },
        stopcounter(){
           this.stopit = !this.stopit;
        },
        generateTitle(){
            this.generateTit = "This message generated at: " + Date.now()
        },
        getAnswer() {
         this.answer = 'Thinking...'
         axios
          .get('https://yesno.wtf/api')
          .then(response => {
            this.answer = response.data.answer
            this.imgSrc = response.data.image
          })
          .catch(error => {
            this.answer = 'Error! Could not reach the API. ' + error
          })
        },
        even(numbers) {
            return numbers.filter(number => number % 2 === 0)
        }
    },
    created() {
    // `this` points to the vm instance
    console.log('count is: ' + this.counter) // => "count is: 1"
    },
    watch: {
        question: function (newValue, oldValue) {
            if (newValue.indexOf('?') > -1) {
                this.getAnswer()
            }
        }
    },
    mounted() {
        setInterval(() => {
          if (!this.stopit) 
            this.counter++
        }, 1000)
    }
})




% end
</html>