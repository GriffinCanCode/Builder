module utils.files.xml;

import std.string;
import std.regex;
import std.algorithm;
import std.array;

/// Lightweight XML attribute extractor
/// Designed for simple XML parsing without full DOM overhead
struct XMLExtractor
{
    private string content;
    
    this(string xmlContent)
    {
        this.content = xmlContent;
    }
    
    /// Extract all elements matching tag name
    Element[] extractElements(string tagName)
    {
        Element[] elements;
        
        // Match self-closing or paired tags
        auto tagPattern = regex(`<` ~ tagName ~ `\s+([^/>]*?)(?:\s*/>|>.*?</` ~ tagName ~ `>)`, "s");
        
        foreach (match; matchAll(content, tagPattern))
        {
            if (match.length >= 2)
            {
                Element elem;
                elem.tagName = tagName;
                elem.attributes = parseAttributes(match[1]);
                elements ~= elem;
            }
        }
        
        return elements;
    }
    
    /// Extract first element matching tag name
    Element extractElement(string tagName)
    {
        auto elements = extractElements(tagName);
        return elements.empty ? Element() : elements[0];
    }
    
    /// Extract text content from tag
    string extractText(string tagName)
    {
        auto pattern = regex(`<` ~ tagName ~ `[^>]*>(.*?)</` ~ tagName ~ `>`, "s");
        auto match = matchFirst(content, pattern);
        return match.empty ? "" : match[1].strip;
    }
    
    /// Parse attributes from attribute string
    private static string[string] parseAttributes(string attrStr)
    {
        string[string] attrs;
        
        auto attrPattern = regex(`(\w+)\s*=\s*"([^"]*)"`);
        
        foreach (match; matchAll(attrStr, attrPattern))
        {
            if (match.length >= 3)
            {
                attrs[match[1]] = match[2];
            }
        }
        
        return attrs;
    }
}

/// XML element representation
struct Element
{
    string tagName;
    string[string] attributes;
    
    /// Get attribute value
    string attr(string name, string defaultValue = "") const
    {
        auto ptr = name in attributes;
        return ptr ? *ptr : defaultValue;
    }
    
    /// Check if attribute exists
    bool hasAttr(string name) const
    {
        return (name in attributes) !is null;
    }
}

/// Extract single tag content (helper function)
string extractTag(string xmlContent, string tagName, string defaultValue = "")
{
    auto extractor = XMLExtractor(xmlContent);
    auto text = extractor.extractText(tagName);
    return text.empty ? defaultValue : text;
}

/// Extract multiple elements (helper function)
Element[] extractElements(string xmlContent, string tagName)
{
    auto extractor = XMLExtractor(xmlContent);
    return extractor.extractElements(tagName);
}

