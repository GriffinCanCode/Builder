module tests.unit.cli.terminal;

import tests.harness;
import frontend.cli.control.terminal;
import std.stdio;

/// Test terminal capabilities detection
void testCapabilitiesDetect()
{
    auto caps = Capabilities.detect();
    
    // Should detect reasonable defaults
    Assert.isTrue(caps.width >= 40, "Terminal width should be at least 40");
    Assert.isTrue(caps.height >= 10, "Terminal height should be at least 10");
    
    // Color support depends on environment, but should not crash
    auto hasColor = caps.supportsColor;
    
    // Unicode support should be detected
    auto hasUnicode = caps.supportsUnicode;
}

/// Test ANSI color codes
void testANSIColors()
{
    // Test foreground colors exist
    Assert.equal(ANSI.FG.length, 16, "Should have 16 foreground colors");
    Assert.equal(ANSI.BG.length, 16, "Should have 16 background colors");
    
    // Test basic colors
    Assert.notEqual(ANSI.FG[Color.Red].length, 0);
    Assert.notEqual(ANSI.FG[Color.Green].length, 0);
    Assert.notEqual(ANSI.FG[Color.Blue].length, 0);
}

/// Test cursor control sequences
void testANSICursor()
{
    auto up = ANSI.cursorUp(5);
    Assert.isTrue(up.length > 0, "Cursor up should return sequence");
    
    auto down = ANSI.cursorDown(3);
    Assert.isTrue(down.length > 0, "Cursor down should return sequence");
    
    auto hide = ANSI.cursorHide();
    Assert.isTrue(hide.length > 0, "Cursor hide should return sequence");
    
    auto show = ANSI.cursorShow();
    Assert.isTrue(show.length > 0, "Cursor show should return sequence");
}

/// Test line control sequences
void testANSILineControl()
{
    auto clear = ANSI.clearLine();
    Assert.isTrue(clear.length > 0, "Clear line should return sequence");
    
    auto clearEOL = ANSI.clearToEOL();
    Assert.isTrue(clearEOL.length > 0, "Clear to EOL should return sequence");
}

/// Test terminal writer
void testTerminalWriter()
{
    auto caps = Capabilities.detect();
    auto term = Terminal(caps, 256); // Small buffer for testing
    
    // Write text
    term.write("Hello");
    term.write(" World");
    
    // Should buffer without crashing
    Assert.isTrue(true, "Terminal write should not crash");
}

/// Test symbols detection
void testSymbolsDetect()
{
    auto caps = Capabilities.detect();
    auto symbols = Symbols.detect(caps);
    
    // Should have all required symbols
    Assert.notEqual(symbols.checkmark.length, 0);
    Assert.notEqual(symbols.cross.length, 0);
    Assert.notEqual(symbols.arrow.length, 0);
    Assert.notEqual(symbols.bullet.length, 0);
}

/// Test unicode vs ASCII symbols
void testSymbolsUnicodeVsAscii()
{
    auto unicode = Symbols.unicode();
    auto ascii = Symbols.ascii();
    
    // Unicode should use special characters
    Assert.equal(unicode.checkmark, "✓");
    Assert.equal(unicode.cross, "✗");
    
    // ASCII should use standard characters
    Assert.equal(ascii.checkmark, "[OK]");
    Assert.equal(ascii.cross, "[FAIL]");
}