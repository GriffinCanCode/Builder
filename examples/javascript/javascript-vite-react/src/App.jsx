import React, { useState } from 'react';
import './App.css';

function App() {
  const [count, setCount] = useState(0);
  const [message, setMessage] = useState('Welcome to Vite + React!');

  const increment = () => {
    setCount(count + 1);
    setMessage(`You clicked ${count + 1} time${count + 1 !== 1 ? 's' : ''}!`);
  };

  const reset = () => {
    setCount(0);
    setMessage('Welcome to Vite + React!');
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>Vite + React Example</h1>
        <p className="message">{message}</p>
        
        <div className="counter-section">
          <button 
            className="btn btn-primary" 
            onClick={increment}
          >
            Click me! ({count})
          </button>
          
          {count > 0 && (
            <button 
              className="btn btn-secondary" 
              onClick={reset}
            >
              Reset
            </button>
          )}
        </div>
        
        <div className="info">
          <p>This example demonstrates:</p>
          <ul>
            <li>⚡️ Lightning-fast Vite bundler</li>
            <li>⚛️ React with JSX</li>
            <li>🎨 CSS modules and styling</li>
            <li>🔥 Hot Module Replacement (HMR)</li>
          </ul>
        </div>
      </header>
    </div>
  );
}

export default App;

