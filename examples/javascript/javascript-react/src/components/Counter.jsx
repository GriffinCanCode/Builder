/**
 * Counter component
 */

import React, { useState } from 'react';

export default function Counter() {
    const [count, setCount] = useState(0);
    
    return (
        <div className="Counter">
            <p>Count: {count}</p>
            <button onClick={() => setCount(count + 1)}>Increment</button>
            <button onClick={() => setCount(count - 1)}>Decrement</button>
            <button onClick={() => setCount(0)}>Reset</button>
        </div>
    );
}

