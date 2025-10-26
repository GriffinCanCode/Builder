<template>
  <div class="app">
    <header class="app-header">
      <h1>Vite + Vue Example</h1>
      <p class="message">{{ message }}</p>
      
      <div class="counter-section">
        <button class="btn btn-primary" @click="increment">
          Click me! ({{ count }})
        </button>
        
        <button 
          v-if="count > 0" 
          class="btn btn-secondary" 
          @click="reset"
        >
          Reset
        </button>
      </div>
      
      <div class="info">
        <p>This example demonstrates:</p>
        <ul>
          <li>⚡️ Lightning-fast Vite bundler</li>
          <li>🖖 Vue 3 Composition API</li>
          <li>🎨 Scoped CSS styling</li>
          <li>🔥 Hot Module Replacement (HMR)</li>
        </ul>
      </div>
    </header>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';

const count = ref(0);

const message = computed(() => {
  if (count.value === 0) {
    return 'Welcome to Vite + Vue!';
  }
  const times = count.value === 1 ? 'time' : 'times';
  return `You clicked ${count.value} ${times}!`;
});

const increment = () => {
  count.value++;
};

const reset = () => {
  count.value = 0;
};
</script>

<style scoped>
.app {
  text-align: center;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #42b883 0%, #35495e 100%);
  color: white;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
}

.app-header {
  max-width: 600px;
  padding: 2rem;
}

h1 {
  font-size: 3rem;
  margin-bottom: 1rem;
  text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.2);
}

.message {
  font-size: 1.5rem;
  margin: 2rem 0;
  font-weight: 500;
}

.counter-section {
  display: flex;
  gap: 1rem;
  justify-content: center;
  margin: 2rem 0;
}

.btn {
  padding: 1rem 2rem;
  font-size: 1.1rem;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.3s ease;
  font-weight: 600;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 8px rgba(0, 0, 0, 0.15);
}

.btn:active {
  transform: translateY(0);
}

.btn-primary {
  background-color: #42b883;
  color: white;
}

.btn-primary:hover {
  background-color: #33a06f;
}

.btn-secondary {
  background-color: #f44336;
  color: white;
}

.btn-secondary:hover {
  background-color: #da190b;
}

.info {
  margin-top: 3rem;
  padding: 1.5rem;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  backdrop-filter: blur(10px);
}

.info p {
  font-size: 1.2rem;
  margin-bottom: 1rem;
}

.info ul {
  list-style: none;
  padding: 0;
}

.info li {
  font-size: 1rem;
  margin: 0.5rem 0;
  text-align: left;
}
</style>

