<?php
// PHP project demonstrating common patterns

echo "=== Builder PHP Example ===\n\n";

// String operations
$message = "Hello from PHP!";
echo "String Operations:\n";
echo "  Original: $message\n";
echo "  Uppercase: " . strtoupper($message) . "\n";
echo "  Length: " . strlen($message) . "\n";

// Array operations
$numbers = [1, 2, 3, 4, 5];
$doubled = array_map(fn($x) => $x * 2, $numbers);
echo "\nArray Operations:\n";
echo "  Original: " . json_encode($numbers) . "\n";
echo "  Doubled: " . json_encode($doubled) . "\n";
echo "  Sum: " . array_sum($numbers) . "\n";

// Associative array
$scores = [
    "Alice" => 95,
    "Bob" => 87,
    "Charlie" => 92
];

echo "\nAssociative Array:\n";
foreach ($scores as $name => $score) {
    echo "  $name: $score\n";
}

// Class example
class Rectangle {
    private $width;
    private $height;
    
    public function __construct($width, $height) {
        $this->width = $width;
        $this->height = $height;
    }
    
    public function area() {
        return $this->width * $this->height;
    }
    
    public function perimeter() {
        return 2 * ($this->width + $this->height);
    }
    
    public function getWidth() {
        return $this->width;
    }
    
    public function getHeight() {
        return $this->height;
    }
}

$rect = new Rectangle(10, 5);
echo "\nRectangle:\n";
echo "  Dimensions: " . $rect->getWidth() . " x " . $rect->getHeight() . "\n";
echo "  Area: " . $rect->area() . "\n";
echo "  Perimeter: " . $rect->perimeter() . "\n";

// Function example
function fibonacci($n) {
    if ($n <= 1) return $n;
    return fibonacci($n - 1) + fibonacci($n - 2);
}

echo "\nFibonacci (first 10):\n";
$fibs = [];
for ($i = 0; $i < 10; $i++) {
    $fibs[] = fibonacci($i);
}
echo "  " . implode(", ", $fibs) . "\n";

