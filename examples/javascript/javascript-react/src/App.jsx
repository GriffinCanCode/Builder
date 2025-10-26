/**
 * React Application Example
 */

import React, { useState } from 'react';
import Counter from './components/Counter';
import './App.css';

function App() {
    const [message, setMessage] = useState('Welcome to Builder + React!');
    
    return (
        <div className="App">
            <header className="App-header">
                <h1>{message}</h1>
                <Counter />
                <button onClick={() => setMessage('Builder is awesome!')}>
                    Change Message
                </button>
            </header>
        </div>
    );
}

export default App;

