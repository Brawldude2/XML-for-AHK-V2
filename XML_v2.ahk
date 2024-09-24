;Native XML parser and serialiser for ahk version 2.0+
;Made by 23sinek345

#Requires AutoHotkey v2.0

GetAllMatchesRegEx(Haystack,NeedleRegEx){
    results := Array()
    RegExMatch(Haystack,NeedleRegEx,&match)
    while(true){
        if(not match){
            break
        }
        results.Push(SubStr(Haystack,match.Pos,match.Len))
        RegExMatch(Haystack,NeedleRegEx,&match,match.Pos+match.Len)
    }
    return results
}

GetFirstMatchRegEx(Haystack,NeedleRegEx){
    RegExMatch(Haystack,NeedleRegEx,&match)
    pos := match.Pos
    len := match.Len
    return SubStr(Haystack,pos,len)
}

class XML{
    Settings := {
        AutomaticSelfClosingTag:true,
        AutomaticOneLineElement:true
    }

    ALLOWED_VAR_CHARS := "[0-9A-Za-zŽžÀ-ÿ:_]"
    REGEX_TAG_NAME := this.ALLOWED_VAR_CHARS "+"
    REGEX_ATTRIBUTE_NAME := "(?<=\s){0,1}" this.ALLOWED_VAR_CHARS "+(?=(\s){0,1}=)"
    REGEX_ATTRIBUTE_VALUE := "(?<==([`"'])).*?(?=\1)"

    DeclarationParse := ["?>"," "]
    AttributeParse := [">"," "]
    QuoteMatch := ["'",'"']
    _TagStack := Array()
    _Content := ""
    _Depth := 0
    _Index := 0
    _XML_Declaration := XML_Element()
    _XML_Container := XML_Element()

    Deserialise(file){
        this._Init()
        this._Read(file)
        this._Content := RegExReplace(this._Content,"\s*=\s*(?=[`"'])","=") ;Replace spaces betwees attribute assignments
        this._Content := StrReplace(this._Content,'=""','=" "') ;Allow regex to find empty attributes
        this._Content := RegExReplace(this._Content,"<!--.*?-->") ;Remove comments
        ;this._Content := StrReplace(this._Content,"`r")
        ;this._Content := StrReplace(this._Content,"`n")
        ;this._Content := StrReplace(this._Content,"`t")
        this.FindUntilNext("<")
        if(this.GetNextChar()=="?"){ ;Read declaration
            this.FindUntilNext("?xml")
            this._ParseVersion()
            this.FindUntilNext("<")
        }
        root := this._Parse(this._XML_Container)
        root.__Declaration := this._XML_Declaration
        return root
    }

    Serialise(XML_Obj,indent_character){
        return SubStr(XML_Obj.toString(indent_character),2) ;Remove leading newline
    }

    _Init(){
        this._TagStack := Array()
        this._Content := ""
        this._Depth := 0
        this._Index := 0
        this._XML_Container := XML_Element()
    }
    
    _Read(file){
        this._Content := FileRead(file)
    }

    _ParseVersion(){
        tag_content := this.FindUntilNext(">")
        this._XML_Declaration.__attrib := this.ExtractAttributes(tag_content)
    }

    _Parse(parent_element){
        curr_element := XML_Element(this._Depth)

        tag_content := this.FindUntilNext(">")
        
        delimeter := SubStr(tag_content,1,1)
        if(delimeter=="?"){ ;PI (Processing Instruction) or xml declaration

        }else if(delimeter=="!"){ ;CDATA or comment

        }else{
            if(!RegExMatch(delimeter,this.ALLOWED_VAR_CHARS)){
                throw Error("XML_Deserialise: Invalid character for start of an element tag.")
            }
        }

        curr_element.tag := GetFirstMatchRegEx(tag_content,this.REGEX_TAG_NAME)
        this._TagStack.Push(curr_element.tag)
        if(InStr(tag_content,"=")){
            curr_element.__attrib := this.ExtractAttributes(tag_content)
        }

        if(SubStr(tag_content,-1,1)=="/"){ ;Self closing tag
            this._TagStack.Pop()
            this._Depth -= 1
            curr_element.__self_close := this.Settings.AutomaticSelfClosingTag
            return curr_element
        }

        while(true){ ;Keep reading until no values left
            value := this.ExtractValueText(this.FindUntilNext("<"))
            
            if(StrLen(RegExReplace(value,"\s+",""))){
                curr_element.appendValue(value)
            }
            
            next_char := this.GetNextChar()

            if(next_char=="/"){ ;Close most recent tag
                this._Index += 1
                _tag := GetFirstMatchRegEx(this.FindUntilNext(">"),this.REGEX_TAG_NAME)
                if(this._TagStack.Pop()==_tag){
                    break
                }else{
                    throw Error("XML_Deserialise: Incorrect tag nesting.")
                }
            }
            this._Depth += 1
            child_element := this._Parse(curr_element)
            curr_element.appendValue(child_element)
        }
        this._Depth -= 1
        return curr_element
    }

    ExtractAttributes(tag_content){ ;Merges attributes while matching to reduce cpu cycles
        str_len := StrLen(tag_content)
        result := Map()
        RegExMatch(tag_content,this.REGEX_ATTRIBUTE_NAME,&m_name)
        RegExMatch(tag_content,this.REGEX_ATTRIBUTE_VALUE,&m_value)
        while(true){
            if(not (m_name and m_value)){ ;Performance reasons
                if(not m_name and not m_value){
                    break
                }else{
                    throw Error("XML_Deserialise: Missing attribute name or value.")
                }
            }
            
            name := SubStr(tag_content,m_name.Pos,m_name.Len)
            value := SubStr(tag_content,m_value.Pos,m_value.Len)
            result[name] := value

            RegExMatch(tag_content,this.REGEX_ATTRIBUTE_NAME,&m_name,m_name.Pos+m_name.Len)
            RegExMatch(tag_content,this.REGEX_ATTRIBUTE_VALUE,&m_value,m_value.Pos+m_value.Len)
        }
        return result
    }

    GetNextChar(len:=1){
        return SubStr(this._Content,this._Index+1,len)
    }

    GetPreviousChar(){
        return SubStr(this._Content,this._Index-1,1)
    }

    ExtractValueText(str){
        return RegExReplace(str,"\s{1,}"," ")
    }

    GetStringUntil(index){
        return SubStr(this._Content,this._Index+1,index-this._Index)
    }

    FindFirstMatchFromSet(match_chars,set_index:=true){
        _min := 999999999
        _char := ""
        for k,char in match_chars{
            _pos := this.FindNext(char)

            if(0 < _pos and _pos < _min){
                _char := char
                _min := _pos
            }
        }
        _val := this.GetStringUntil(_min-1)
        this._Index := _min
        return {char:_char,value:_val}
    }

    FindNext(search_str){
        return InStr(this._Content,search_str,true,this._Index+1)
    }

    FindUntilNext(search_str,set_index:=true){
        _pos := InStr(this._Content,search_str,true,this._Index+1)
        _str := this.GetStringUntil(_pos-1)

        if(set_index){
            this._Index := _pos + StrLen(search_str)-1
        }

        return _str
    }
}

class XML_Element{
    tag := ""
    __attrib := Map()
    __value := Array()
    __namespace := "" ;Unused at the moment

    __self_close := false

    __New(depth:=0){
        this.depth := depth
    }

    __Get(key,param){
        if(this.__attrib.Has(key)){
            return this.__attrib.Get(key)
        }
        try{
            if(Number(key) is Integer){
                if(key > 0 and key <= this.__value.Length){
                    return this.__value.Get(key)
                }
            }
        }catch{
            return
        }
    }

    __Item := this.__attrib

    setValue(val){
        this.__value := Array(val)
    }

    appendValue(val){
        this.__value.Push(val)
    }

    setAttribute(key,val){
        this.__attrib[key] := val
    }

    getValues(){
        return this.__value
    }

    getChildren(){
        return this.__value
    }

    getAttributes(){
        return this.__attrib
    }

    toString(indent_character){
        str := ""

        if(this.HasProp("__Declaration")){
            if(this.__Declaration.__attrib.Count){
                str := str " <?xml"
                for k,v in this.__Declaration.__attrib{
                    if(InStr(v,'"') and InStr(v,"'")){
                        throw Error("XML_Serialise: Cant have both quote symbols at the same time.")
                    }
                    str := str " " k '="' v '"'
                }
                str := str "?>"
            }
        }

        one_line_element := true
        indented := "`n"
        loop this.depth{
            indented := indented indent_character
        }
        str := str indented "<" this.tag

        for k,v in this.__attrib{
            if(InStr(v,'"') and InStr(v,"'")){
                throw Error("XML_Serialise: Cant have both quote symbols at the same time.")
            }
            str := str " " k '="' v '"'
        }
        
        if(this.__self_close){
            str := str " />"
            return str
        }

        str := str ">"
        
        for k,v in this.__value{
            if(v is XML_Element){
                one_line_element := false
                str := str . v.toString(indent_character)
            }else{
                str := str . v
            }
            
        }
        if(!one_line_element){
            str := str indented
        }
        str := str "</" this.tag ">"
        return str
    }
}