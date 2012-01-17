/*
   Copyright 2009 - Gonzalo Huerta-Canepa

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

*/

/**
* This library lets you use a template (newly created or imported from a PDF file)
* in your AlivePDF-based application. 
* PDFTemplate and PDFi are based on the FPDI_TPL and FPDI PHP libraries by Jan Slabon (http://www.setasign.de/)
* Core Team : Gonzalo Huerta-Canepa
* @version 0.1.0 Current Release
* @url http://gonzalo.huerta.cl
*/

package cl.huerta.pdf
{
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.getDefinitionByName;
	
	import mx.utils.StringUtil;
	
	import org.alivepdf.tools.sprintf;
	
	public class PDFParser
	{
		public static const PDF_TYPE_NULL:Number       = 0;
		public static const PDF_TYPE_NUMERIC:Number    = 1;
		public static const PDF_TYPE_TOKEN:Number      = 2;
		public static const PDF_TYPE_HEX:Number        = 3;
		public static const PDF_TYPE_STRING:Number     = 4;
		public static const PDF_TYPE_DICTIONARY:Number = 5;
		public static const PDF_TYPE_ARRAY:Number      = 6;
		public static const PDF_TYPE_OBJDEC:Number     = 7;
		public static const PDF_TYPE_OBJREF:Number     = 8;
		public static const PDF_TYPE_OBJECT:Number     = 9;
		public static const PDF_TYPE_STREAM:Number     = 10;
		public static const PDF_TYPE_BOOLEAN:Number    = 11;
		public static const PDF_TYPE_REAL:Number       = 12;
		
		public static const LINE_BREAK_10:String = String.fromCharCode(10);
		public static const LINE_BREAK_13:String = String.fromCharCode(13);

		/**
		 * Filename
		 * @var string
		 */
		protected var _filename:String;
		public function get filename():String {
			return this._filename;
		}
		/**
		 * File resource
		 * @var resource
		 */
		protected var f:*;
		/**
		 * Stream to file
		 * @var FileStream
		 */
		protected var stream:*;
		/**
		 * PDF Context
		 * @var object pdf_context-Instance
		 */
		protected var _c:PDFContext;
		public function get c():PDFContext {
			return this._c;
		}
		/**
		 * xref-Data
		 * @var array
		 */
		protected var xref:Dictionary;
		/**
		 * root-Object
		 * @var array
		 */
		protected var root:Array;
		/**
		 * PDF version of the loaded document
		 * @var string
		 */
		protected var pdfVersion:String;
		
		protected var actualObj:Array;

		public function PDFParser(filename_:String)
		{
			this._filename = filename_;
			
//			this.f = new File(filename_); //@fopen(this.filename, 'rb');
			var fileClass:Class = getDefinitionByName("flash.filesystem.File") as Class;
			this.f = new fileClass(this._filename);
			
			var methodExist:Boolean;
			try {
				methodExist = this.f["exists"] !=null;
			} catch (e:Error) {
				methodExist = false;
			} finally {
			}
			if (!methodExist)
				throw new Error(sprintf('Invalid file object for %s !', filename_));
			if (!f.exists)
			    throw new Error(sprintf('Cannot open %s !', filename_));

			var streamClass:Class = getDefinitionByName("flash.filesystem.FileStream") as Class;
			this.stream = new streamClass();
			this.stream.open(f, "read");
			
			this.getPDFVersion();
			
			this._c = new PDFContext(this.stream);
			
			this.xref = new Dictionary();
			// Read xref-Data
			this.pdfReadXref(this.xref, this.pdfFindXref());
			
			// Check for Encryption
			this.getEncryption();
			
			// Read root
			this.pdfReadRoot();
		}
    
		/**
		 * Close the opened file
		 */
		public function closeFile():void {
			if (this.stream != null) {
			    this.stream.close();	
				this.f = null;
			}	
		}

		
		/**
		 * Check Trailer for Encryption
		 */
		protected function getEncryption():void {
		    if (!(this.xref['trailer'][1] is Dictionary))
		    	throw new Error('Invalid trailer object!');
		    if (this.xref['trailer'][1]['/Encrypt'] != null) {
		        throw new Error('File is encrypted!');
		    }
		}
		
		/**
		 * Find/Return /Root
		 *
		 * @return array
		 */
		protected function pdfFindRoot():Array {
		    if (!(this.xref['trailer'][1] is Dictionary))
		    	throw new Error('Invalid trailer object!');
		    if (this.xref['trailer'][1]['/Root'][0] != PDF_TYPE_OBJREF) {
		        throw new Error('Wrong Type of Root-Element! Must be an indirect reference');
		    }
		    return this.xref['trailer'][1]['/Root'];
		}

		/**
		 * Read the /Root
		 */
		protected function pdfReadRoot():void {
		    // read root
		    this.root = this.pdfResolveObject(this._c, this.pdfFindRoot());
		}
		
		/**
		 * Get PDF-Version
		 *
		 * And reset the PDF Version used in FPDI if needed
		 */
		protected function getPDFVersion():String {
		    this.stream.position = 0;
		    var pdfInfo:String = this.stream.readMultiByte(16, "windows-1252");
		    var m:Array = pdfInfo.match(/\d\.\d/); 
		    if (m[0] != null)
		        this.pdfVersion = m[0];
		    return this.pdfVersion;
		}
		
		/**
		 * Find the xref-Table
		 */
		protected function pdfFindXref():Number {
		   	var toRead:Number = 150;
		            
		    var stat:Number = this.f.size - toRead; 
		    if (stat < 0) {
		        toRead += stat;
		        stat = 0;
		    }
		    this.stream.position = stat;
		   	var data:String = this.stream.readMultiByte(toRead,"windows-1252");
		   	var pos:Number = data.lastIndexOf('startxref') + 9;
//		    var pos:Number = data.length - reverse(data).indexOf(reverse('startxref'));
		    data = data.substr(pos);
		    
		    var matches:Array = data.match(/\s*(\d+).*$/s); 
		    if (matches == null || matches.length < 2 || matches[1] == null) {
		        throw new Error('Unable to find pointer to xref table');
			}
		
			return parseInt(matches[1]);
		}
		
		protected function reverse(in_:String):String {
			return in_.split("").reverse().join("");
		}
		
		protected function arrayUnique(ac:Array) : Array {
		    var i:int, j:int;
		    var result:Array = clone(ac);
		    for (i = 0; i < result.length - 1; i++)
		        for (j = i + 1; j < result.length; j++)
		            if (result[i] === result[j])
		                result.splice(j, 1);
		    return result;
		}
		
		protected function arrayNoEmpty(ac:Array) : Array {
		    var i:int, j:int;
		    var result:Array = clone(ac);
		    for (i = 0; i < result.length - 1; i++)
		    	if (result[i].length == 0 || result[i] == "\r" || result[i] == "\n" || result[i] == "\r\n")
	                result.splice(i--, 1);
		    return result;
		}
		
		protected function clone(source:Object):*
		{
		    var myBA:ByteArray = new ByteArray();
		    myBA.writeObject(source);
		    myBA.position = 0;
		    return(myBA.readObject());
		}


		/**
		 * Read xref-table
		 *
		 * @param array $result Array of xref-table
		 * @param integer $offset of xref-table
		 */
		protected function pdfReadXref(result:Dictionary, offset:Number):Boolean {
			var o_pos:Number = offset - 20;
		    this.stream.position = o_pos;
		        
		    var data:String = this.stream.readMultiByte(Math.min(100, this.stream.bytesAvailable),"windows-1252");
		    
		    var xrefPos:Number = data.indexOf('xref');
		    
		    if (xrefPos < 0) {
		        throw new Error('Unable to find xref table.');
		    }
		    
		    if (result['xref_location'] == undefined || result['xref_location'] == null) {
		        result['xref_location'] = o_pos+xrefPos;
		        result['max_object']    = 0;
			}
		
		    var bytesPerCycle:Number = Math.min(100, this.stream.bytesAvailable);
		    
		    o_pos += xrefPos + 4;
		    this.stream.position = o_pos; 
		    data = this.stream.readMultiByte(bytesPerCycle,"windows-1252");
		    
		    var currentPos:Number = 0;
		    var trailerPos:Number = data.indexOf('trailer',currentPos);
		    while(trailerPos < 0 && this.stream.bytesAvailable > 0) {
		    	currentPos += bytesPerCycle;
		    	bytesPerCycle = Math.min(100, this.stream.bytesAvailable);
		    	data += this.stream.readMultiByte(bytesPerCycle,"windows-1252");
			    trailerPos = data.indexOf('trailer', currentPos);
		    }
		    
		    if (trailerPos < 0) {
		        throw new Error('Trailer keyword not found after xref table');
		    }
		    
		    data = data.substr(0, trailerPos);
		    
		    // get Line-Ending
		    var m:Array = data.substr(0,100).match(/(\r\n|\n|\r)/g); // check the first 100 bytes for linebreaks
		
		    var differentLineEndings:Number = arrayUnique(m).length;
		    var lines:Array;
		    if (differentLineEndings > 1) {
		        lines = data.split(/(\r\n|\n|\r)/); //TODO: remove empty objects
		    } else {
		        lines = data.split(m[0]);
		    }
		    lines = arrayNoEmpty(lines);
		    
		    data = undefined;
		    differentLineEndings = undefined;
		    m = null; 
		    m = undefined;

		    var linesCount:Number = lines.length;
		    
		    var start:Number = 1;
            var end:Number;
		    
		    for (var i:Number = 0; i < linesCount; i++) {
		        var line:String = StringUtil.trim(lines[i] as String);
		        if (line.length > 0) {
		            var pieces:Array = line.split(' ');
		            var nps:Number = pieces.length;
		            switch(nps) {
		                case 2:
		                    start = parseInt(pieces[0]);
		                    end   = start+parseInt(pieces[1]);
		                    if (end > result['max_object'])
		                        result['max_object'] = end;
		                    break;
		                case 3:
		                	if (result['xref'] == undefined || result['xref'] == null)
		                		result['xref'] = new Array(); 
		                    if (result['xref'][start] == undefined || result['xref'][start] == null)
		                        result['xref'][start] = new Array();
		                    
		                    var gen:Number = parseInt(pieces[1]);
		                    if (result['xref'][start][gen] == undefined) {
		            	        result['xref'][start][gen] = (pieces[2] == 'n') ? parseInt(pieces[0]) : null;
		            	    }
		                    start++;
		                    break;
		                default:
		                    throw new Error('Unexpected data in xref table');
		            }
		        }
		    }
		    
		    this.stream.position = o_pos+trailerPos+7;
		    var c:PDFContext =  new PDFContext(this.stream);
		    var trailer:* = this.pdfReadValue(c);
		    
		    c = null;
		    c = undefined;

		    if (result['trailer'] == undefined || result['trailer'] == null) {
		        result['trailer'] = trailer;          
		    }
		    
		    if (trailer[1] is Dictionary && trailer[1]['/Prev'] != undefined) {
		        this.pdfReadXref(result, trailer[1]['/Prev'][1]);
		    } 
		    
		    trailer = null;
		    trailer = undefined;
		    
		    return true;
		}
		
		/**
		 * Reads an Value
		 *
		 * @param object $c pdf_context
		 * @param string $token a Token
		 * @return mixed
		 */
		protected function pdfReadValue(c:PDFContext, token:* = null):* {
			if (token == null) {
			    token = this.pdfReadToken(c);
			}
			
		    if (token === false) {
			    return false;
			}
		
			var result:*;
			var pos:Number;
			var key:*;
			var value:*;
			switch (token) {
		        case '<':
					// This is a hex string.
					// Read the value, then the terminator
		
		            pos = c.offset;
		
					while(1) {
		
		                var match:Number = c.buffer.indexOf('>', pos);
					
						// If you can't find it, try
						// reading more data from the stream
		
						if (match < 0) {
							if (!c.increaseLength()) {
								return false;
							} else {
		                    	continue;
		                	}
						}
		
						result = c.buffer.substr(c.offset, match - c.offset);
						c.offset = match + 1;
						
						return [PDF_TYPE_HEX, result];
		            }
		            
		            break;
				case '<<':
					// This is a dictionary.
		
					result = new Dictionary();
		
					// Recurse into this function until we reach
					// the end of the dictionary.
					key = this.pdfReadToken(c);
					while (key !== '>>') {
						trace(key);
						
						if (key === false) {
							return false;
						}
						
						value = this.pdfReadValue(c);
						if (value === false) {
							return false;
						}
						
						// Catch missing value
						if (value[0] == PDF_TYPE_TOKEN && value[1] == '>>') {
						    result[key] = [PDF_TYPE_NULL];
						    break;
						}
						
						result[key] = value;
						key = this.pdfReadToken(c);
					}
					
					return [PDF_TYPE_DICTIONARY, result];
		
				case '[':
					// This is an array.
		
					result = new Array();
		
					// Recurse into this function until we reach
					// the end of the array.
					var token:* = this.pdfReadToken(c);
					while (token !== ']') {
		                if (token === false) {
							return false;
						}
						
						value = this.pdfReadValue(c,token);
						if (value === false) {
		                    return false;
						}
						
						result.push(value); //OK
						token = this.pdfReadToken(c);
					}
					
		            return [PDF_TYPE_ARRAY, result];
		
				case	'('		:
		            // This is a string
		            pos = c.offset;
		            
		            var openBrackets:Number = 1;
					do {
		                for (; openBrackets != 0 && pos < c.length; pos++) {
		                    switch (c.buffer.charCodeAt(pos)) {
		                        case 0x28: // '('
		                            openBrackets++;
		                            break;
		                        case 0x29: // ')'
		                            openBrackets--;
		                            break;
		                        case 0x5C: // backslash
		                            pos++;
		                    }
		                }
					} while(openBrackets != 0 && c.increaseLength());
					
					result = c.buffer.substr(c.offset, pos - c.offset - 1);
					c.offset = pos;
					
					return [PDF_TYPE_STRING, result];
		
					
		        case 'stream':
		        	var o_pos:Number    = c.stream.position - c.bbuffer.length;
			        var o_offset:Number = c.offset;
			        
			        var startpos:Number = o_pos + o_offset;
			        c.reset(startpos);
			        
			        var e:Number = 0; // ensure line breaks in front of the stream
			        if (c.buffer.charAt(0) == LINE_BREAK_10 || c.buffer.charAt(0) == LINE_BREAK_13)
			        	e++;
			        if (c.buffer.charAt(1) == LINE_BREAK_10 && c.buffer.charAt(0) != LINE_BREAK_10)
			        	e++;
			        
			        var length:Number = 0;
			        if (this.actualObj[1][1]['/Length'][0] == PDF_TYPE_OBJREF) {
			        	var tmp_c:PDFContext = new PDFContext(this.stream);
			        	var tmp_length:Number = this.pdfResolveObject(tmp_c,this.actualObj[1][1]['/Length']);
			        	length = tmp_length[1][1];
			        } else {
			        	length = this.actualObj[1][1]['/Length'][1];	
			        }
			        
			        var v:ByteArray = new ByteArray();
			        if (length > 0) {
				        c.reset(startpos+e,length);
				        c.bbuffer.readBytes(v,0,length);
					    v.position = 0;
				        //v = clone(c.bbuffer);
			        }
			        c.reset(startpos+e+length+9); // 9 = strlen("endstream")
			        
			        return [PDF_TYPE_STREAM, v];
			        
		        default	:
		        	if (!isNaN(parseInt(token))) {
		                // A numeric token. Make sure that
						// it is not part of something else.
						var tok2:* = this.pdfReadToken(c);
						if (tok2 !== false) {
		                    if (!isNaN(parseInt(tok2))) {
		
								// Two numeric tokens in a row.
								// In this case, we're probably in
								// front of either an object reference
								// or an object specification.
								// Determine the case and return the data
								var tok3:* = this.pdfReadToken(c);
								if (tok3 !== false) {
		                            switch (tok3) {
										case	'obj'	:
		                                    return [PDF_TYPE_OBJDEC, parseInt(token), parseInt(tok2)];
										case	'R'		:
											return [PDF_TYPE_OBJREF, parseInt(token), parseInt(tok2)];
									}
									// If we get to this point, that numeric value up
									// there was just a numeric value. Push the extra
									// tokens back into the stack and return the value.
									c.stack.push(tok3);
								}
							}
		
							c.stack.push(tok2);
						}
		
						if (token === (parseInt(token) as Number).toString())
		    				return [PDF_TYPE_NUMERIC, parseInt(token)];
						else 
							return [PDF_TYPE_REAL, parseFloat(token)];
					} else if (token == 'true' || token == 'false') {
		                return [PDF_TYPE_BOOLEAN, token == 'true'];
					} else if (token == 'null') {
					   return [PDF_TYPE_NULL];
					} else {
		                // Just a token. Return it.
						return [PDF_TYPE_TOKEN, token];
					}
		
		     }
		}

		/**
		 * Resolve an object
		 *
		 * @param object $c pdf_context
		 * @param array objSpec The object-data
		 * @param boolean $encapsulate Must set to true, cause the parsing and fpdi use this method only without this para
		 */
		public function pdfResolveObject(c:PDFContext, objSpec:Array, encapsulate:Boolean = true):* {
		    // Exit if we get invalid data
			if (objSpec[0] == PDF_TYPE_OBJREF) {
		
				// This is a reference, resolve it
				if (this.xref['xref'][objSpec[1]][objSpec[2]] != undefined) {
		
					// Save current file position
					// This is needed if you want to resolve
					// references while you're reading another object
					// (e.g.: if you need to determine the length
					// of a stream)
		
					var old_pos:Number = c.stream.position;
		
					// Reposition the file pointer and
					// load the object header.
					
					c.reset(this.xref['xref'][objSpec[1]][objSpec[2]]);
		
					var header:* = this.pdfReadValue(c);
		
					if (header[0] != PDF_TYPE_OBJDEC || header[1] != objSpec[1] || header[2] != objSpec[2]) {
						throw new Error("Unable to find object ({objSpec[1]}, {objSpec[2]}) at expected location");
					}
		
					// If we're being asked to store all the information
					// about the object, we add the object ID and generation
					// number for later use
					var result:Array;
					var index:Number = 0;
					if (encapsulate) {
						result = [
							PDF_TYPE_OBJECT,
							{obj: objSpec[1]},
							{gen: objSpec[2]}
						];
						index = 1;
					} else {
						result = new Array();
					}
					this.actualObj = result;
		
					// Now simply read the object data until
					// we encounter an end-of-object marker
					while(1) {
		                var value:* = this.pdfReadValue(c);
						if (value === false || result.length > 4) {
							// in this case the parser coudn't find an endobj so we break here
							break;
						}
		
						if (value[0] == PDF_TYPE_TOKEN && value[1] === 'endobj') {
							break;
						}

						result.splice(index++,0,value);
//		                result.push(value);
					}
		
					c.reset(old_pos);
		
		            if (result[2][0] != undefined && result[2][0] == PDF_TYPE_STREAM) {
		                result[0] = PDF_TYPE_STREAM;
		            }
		
					return result;
				}
			} else {
				return objSpec;
			}
		}
		
		protected function strspn(target_:String, allowed_:String, start_:Number=0):Number {
			var t:String = target_.substr(start_);
			var idx:Number = t.length;
			for(var i:Number = 0; allowed_.indexOf(t.charAt(i))>=0 && i<idx; i++);
			return i;
		}
		
		protected function strcspn(target_:String, filter_:String, start_:Number=0):Number {
			var t:String = target_.substr(start_);
			var idx:Number = t.length;
			for(var i:Number = 0; filter_.indexOf(t.charAt(i))<0 && i<idx; i++);
			return i;
		}
		
		/**
		 * Reads a token from the file
		 *
		 * @param object $c pdf_context
		 * @return mixed
		 */
		protected function pdfReadToken(c:PDFContext):*
		{
			// If there is a token available
			// on the stack, pop it out and
			// return it.
		
			if (c.stack.length > 0) {
				return c.stack.pop();
			}
		
			// Strip away any whitespace
			do {
				if (!c.ensureContent()) {
					return false;
				}
				c.offset += strspn(c.buffer, " \n\r\t", c.offset);
			} while (c.offset >= c.length - 1);
		
			// Get the first character in the stream
		
			var char:String = c.buffer.charAt(c.offset++);
			var pos:Number;
			switch (char) {
		
				case '['	:
				case ']'	:
				case '('	:
				case ')'	:
				
					// This is either an array or literal string
					// delimiter, Return it
		
					return char;
		
				case '<'	:
				case '>'	:
		
					// This could either be a hex string or
					// dictionary delimiter. Determine the
					// appropriate case and return the token
		
					if (c.buffer.charAt(c.offset) == char) {
						if (!c.ensureContent()) {
						    return false;
						}
						c.offset++;
						return char + char;
					} else {
						return char;
					}
		
				case '%'    :
				    
				    // This is a comment - jump over it!
				    
		            pos = c.offset;
					while(1) {
						var m:Array = c.buffer.substr(pos).match(/(\r\n|\r|\n)/);
					    var match:Number = m.length;
		                if (match === 0) {
							if (!c.increaseLength()) {
								return false;
							} else {
		                    	continue;
		                	}
						}
		
						c.offset = c.buffer.indexOf(m[0], pos) + m[0].length;
						
						return this.pdfReadToken(c);
		            }
		            
				default		:
		
					// This is "another" type of token (probably
					// a dictionary entry or a numeric value)
					// Find the end and return it.
		
					if (!c.ensureContent()) {
						return false;
					}
		
					while(1) {
		
						// Determine the length of the token
		
						pos = strcspn(c.buffer, " %[]<>()\r\n\t/", c.offset);
						if (c.offset + pos <= c.length - 1) {
							break;
						} else {
							// If the script reaches this point,
							// the token may span beyond the end
							// of the current buffer. Therefore,
							// we increase the size of the buffer
							// and try again--just to be safe.
		
							c.increaseLength();
						}
					}
		
					var result:String = c.buffer.substr(c.offset - 1, pos + 1);
		
					c.offset += pos;
					return result;
			}
		}

	}
}