# XML-for-AHK-V2
XML Serialiser/Deserialiser for ahk version 2.0+
## Usage
```
#Include XML_v2.ahk
newParser := XML()
xml_object := newParser.Deserialise(file_path) ;Deserialise given file
text_output := newParser.Serialise(xml_object) ;Serialise the xml object
```
