# XML-for-AHK-V2
XML Serialiser/Deserialiser for ahk version 2.0+
## Usage
```
#Include XML_v2.ahk
newParser := XML()
xml_object := newParser.Deserialise(file_path) ;Deserialise given file
text_output := newParser.Serialise(xml_object) ;Serialise the xml object
```

## Navigating around elements
`XML_Element.getChildren()[Children Index]` to navigate around.
You can also use `XML_Element["Attribute Name"]` or `XML_Element.getAttributes()` to get all attributes.
