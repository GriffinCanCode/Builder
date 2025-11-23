/**
 * String utility functions
 */

/**
 * Format a number with thousand separators
 * @param {number} num - Number to format
 * @returns {string} Formatted string
 */
export function format(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

/**
 * Parse a formatted number string
 * @param {string} str - String to parse
 * @returns {number} Parsed number
 */
export function parse(str) {
    return parseFloat(str.replace(/,/g, ''));
}

