/**
 * UI rendering utilities
 */

export function renderResults(container, results) {
    container.innerHTML = results.join('<br>');
}

export function createElement(tag, className, content) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (content) element.textContent = content;
    return element;
}

