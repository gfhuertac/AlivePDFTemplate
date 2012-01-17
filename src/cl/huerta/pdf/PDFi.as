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
	import flash.utils.CompressionAlgorithm;
	import flash.utils.Dictionary;
	
	import org.alivepdf.layout.Size;
	import org.alivepdf.tools.sprintf;
	
	public class PDFi extends PDFTemplate
	{
        protected static const PDFI_VERSION:String = '1.3';
		
		/**
		 * Actual filename
		 * @var string
		 */
		protected var current_filename:String;
		
		/**
		 * Parser-Objects
		 * @var array
		 */
		protected var parsers:Dictionary;
		
		/**
		 * Current parser
		 * @var object
		 */
		protected var current_parser:PDFiPDFParser;
		
		/**
		 * object stack
		 * @var array
		 */
		protected var _obj_stack:Dictionary = new Dictionary();
		
		/**
		 * done object stack
		 * @var array
		 */
		protected var _don_obj_stack:Dictionary = new Dictionary();
		
		/**
		 * Current Object Id.
		 * @var integer
		 */
		protected var _current_obj_id:Number;
		
		/**
		 * The name of the last imported page box
		 * @var string
		 */
		protected var lastUsedPageBox:String;
		
		protected var _importedPages:Dictionary = new Dictionary();


		public function PDFi(orientation:String='Portrait', unit:String='Mm', autoPageBreak:Boolean=true, pageSize:Size=null, rotation:int=0)
		{
			//TODO: implement function
			super(orientation, unit, autoPageBreak, pageSize, rotation);
			parsers = new Dictionary();
		}
		
		public function get _k():Number {
			return this.k;
		}
		
		public function get _pdfVersion():String {
			return this.version;
		}
		
		public function set _pdfVersion(newValue_:String):void {
			this.version = newValue_;
		}
		
	    /**
	     * Set a source-file
	     *
	     * @param string $filename a valid filename
	     * @return int number of available pages
	     */
	    public function setSourceFile(filename:String):Number {
	        this.current_filename = filename;
	
	        if (this.parsers[current_filename] == undefined || this.parsers[current_filename] == null)
	            this.parsers[current_filename] = new PDFiPDFParser(current_filename, this);
	        this.current_parser = this.parsers[current_filename];
	        
	        return (this.parsers[current_filename] as PDFiPDFParser).getPageCount();
	    }

		/**
		 * Import a page
		 *
		 * @param int $pageno pagenumber
		 * @return int Index of imported page - to use with fpdf_tpl::useTemplate() or false
		 */
		public function importPage(pageno:Number, boxName:String='/CropBox'):* {
		    if (this._intpl) {
		        throw new Error('Please import the desired pages before creating a new template.');
		    }
		    
		    // check if page already imported
		    var pageKey:String = this.current_filename + pageno + boxName;
		    if (this._importedPages[pageKey] != undefined && this._importedPages[pageKey] != null)
		        return this._importedPages[pageKey];
		    
		    var parser:PDFiPDFParser = this.parsers[this.current_filename];
		    parser.setPageNo(pageno);
		
		    this.tpl++;
		    this.tpls[this.tpl] = new Array();
		    var tpl:Object = this.tpls[this.tpl];
		    tpl.parser    = parser;
		    tpl.resources = parser.getPageResources();
		    tpl.buffer    = parser.getContent();
		    
		    if (PDFiPDFParser.availableBoxes.indexOf(boxName) < 0)
		        throw new Error(sprintf('Unknown box: %s', boxName));
		    var pageboxes:Dictionary = parser.getPageBoxes(pageno);
		    
		    /**
		     * MediaBox
		     * CropBox: Default -> MediaBox
		     * BleedBox: Default -> CropBox
		     * TrimBox: Default -> CropBox
		     * ArtBox: Default -> CropBox
		     */
		    if ((pageboxes[boxName] == undefined || pageboxes[boxName] == null) && (boxName == '/BleedBox' || boxName == '/TrimBox' || boxName == '/ArtBox'))
		        boxName = '/CropBox';
		    if ((pageboxes[boxName] == undefined || pageboxes[boxName] == null) && boxName == '/CropBox')
		        boxName = '/MediaBox';
		    
		    if (pageboxes[boxName] == undefined || pageboxes[boxName] == null)
		        return false;
		    this.lastUsedPageBox = boxName;
		    
		    var box:* = pageboxes[boxName];
		    tpl.box = box;
		    
		    // To build an array that can be used by PDF_TPL::useTemplate()
			for (var prop:* in box) {
				this.tpls[this.tpl][prop] = box[prop];
			}
		    //this.tpls[this.tpl] = array_merge(this.tpls[this.tpl],$box); 
		    
		    // An imported page will start at 0,0 everytime. Translation will be set in _putformxobjects()
		    tpl.x = 0;
		    tpl.y = 0;
		    
		    var page:Array = parser.pages[parser.getPageNo()+4];
		    
		    // handle rotated pages
		    var rotation:* = parser.getPageRotation(pageno);
		    tpl._rotationAngle = 0;
		    if (rotation !== false && rotation is Array && rotation.length > 1 && rotation[1] != undefined && rotation[1] is Number) {
			    var angle:Number = rotation[1] % 360;
			    if (angle != 0) {
			        var steps:Number = angle / 90;
			            
			        var _w:Number = tpl.w;
			        var _h:Number = tpl.h;
			        tpl.w = (steps % 2 == 0) ? _w : _h;
			        tpl.h = (steps % 2 == 0) ? _h : _w;
			        
			        tpl._rotationAngle = angle*-1;
			    }
		    }
		    
		    this._importedPages[pageKey] = this.tpl;
		    
		    return this.tpl;
		}
		
		public function getLastUsedPageBox():String {
		    return this.lastUsedPageBox;
		}

		override public function useTemplate(tplidx:Number, _x:Number=NaN, _y:Number=NaN, _w:Number=0, _h:Number=0, adjustPageSize:Boolean=false): Object {
		    if (adjustPageSize == true && isNaN(_x) && isNaN(_y)) {
		        var size:* = this.getTemplateSize(tplidx, _w, _h);
		        var format:Array = [size.w, size.h];
		        if (format[0]!=this.currentPage.size.dimensions[0] || format[1]!=this.currentPage.size.dimensions[1]) {
		            this.currentPage.w=format[0];
		            this.currentPage.h=format[1];
		            this.currentPage.wPt=this.currentPage.w*this.k;
		    		this.currentPage.hPt=this.currentPage.h*this.k;
		    		this.pageBreakTrigger=this.currentPage.h-this.bottomMargin;
//		    		this.currentPage.width = format[0];
//		    		this.currentPage.height = format[1];
//TODO: add the new size!!!
//		    		this.pageSizes[this.page]= [this.currentPage.wPt, this.currentPage.hPt];
		        }
		    }
		    
		    this.write('q 0 J 1 w 0 j 0 G 0 g'); // reset standard values
		    var s:* = super.useTemplate(tplidx, _x, _y, _w, _h, adjustPageSize);
		    this.write('Q');
		    return s;
		}
		
		/**
		 * Private method, that rebuilds all needed objects of source files
		 */
		protected function writeImportedObjects():void {
		    if (this.parsers != null) {
		    	var filename:String;
		    	var p:*;
		        for (filename in this.parsers) {
		        	p = this.parsers[filename];
		            this.current_parser = this.parsers[filename];
		            var os:* = this._obj_stack[filename];
		            if (os != undefined && os != null && os is Array) {
		            	while (os.length > 0) {
		            		var n:* = (os as Array).shift();
		            		if (n == undefined)
		            			continue;
		            		var nObj:* = (this.current_parser as PDFParser).pdfResolveObject(this.current_parser.c, n[1]);
							
		                    this.newObjE(n[0]);
		                    
		                    if (nObj[0] == PDFParser.PDF_TYPE_STREAM) {
								this.pdfWriteValue(nObj);
		                    } else {
		                        this.pdfWriteValue(nObj[1]);
		                    }
		                    
		                    this.write('endobj');
		                }
		            }
		        }
		    }
		}
			
		/**
		 * Private Method that writes the form xobjects
		 */
	    override protected function writeFormXObjects():void {
			var compress:Boolean = (this.currentPage in this.compressedPages);
	        var filter:String=(compress) ? '/Filter /FlateDecode ' : '';
			var idx:Number = this.tpls.length;
			var tplidx:Number = 0;
			var tpl:Object;
	        for(tplidx=1;tplidx<idx;tplidx++) {
	        	tpl = this.tpls[tplidx];
	    		this.newObjE();
	    		this.tpls[tplidx].n = this.n;
				
				this.write('<<'+filter+'/Type /XObject');
		        this.write('/Subtype /Form');
		        this.write('/FormType 1');
		        
		        this.write(sprintf('/BBox [%.2F %.2F %.2F %.2F]', 
		            ((tpl.box != undefined && tpl.box['llx'] != undefined) ? tpl.box['llx'] : tpl.x)*this.k,
		            ((tpl.box != undefined && tpl.box['lly'] != undefined) ? tpl.box['lly'] : -tpl.y)*this.k,
		            ((tpl.box != undefined && tpl.box['urx'] != undefined) ? tpl.box['urx'] : tpl.w + tpl.x)*this.k,
		            ((tpl.box != undefined && tpl.box['ury'] != undefined) ? tpl.box['ury'] : tpl.h-tpl.y)*this.k
		        ));
		        
		        var c:Number  = 1;
		        var s:Number  = 0;
		        var tx:Number = 0;
		        var ty:Number = 0;
		        
		        if (tpl.box != undefined) {
		            tx = -tpl.box['llx'];
		            ty = -tpl.box['lly'];
		            
		            if (tpl._rotationAngle != 0) {
		                var angle:Number = tpl._rotationAngle * Math.PI/180;
		                c=Math.cos(angle);
		                s=Math.sin(angle);
		                
		                switch(tpl._rotationAngle) {
		                    case -90:
		                       tx = -tpl.box['lly'];
		                       ty = tpl.box['urx'];
		                       break;
		                    case -180:
		                        tx = tpl.box['urx'];
		                        ty = tpl.box['ury'];
		                        break;
		                    case -270:
		                        tx = tpl.box['ury'];
		                        ty = 0;
		                        break;
		                }
		            }
		        } else if (tpl.x != 0 || tpl.y != 0) {
		            tx = -tpl.x*2;
		            ty = tpl.y*2;
		        }
		        
		        tx *= this.k;
		        ty *= this.k;
		        
		        if (c != 1 || s != 0 || tx != 0 || ty != 0) {
		            this.write(sprintf('/Matrix [%.5F %.5F %.5F %.5F %.5F %.5F]',
		                c, s, -s, c, tx, ty
		            ));
		        }
		        
		        this.write('/Resources ');
		
		        if (tpl.resources != undefined) {
		            this.current_parser = tpl.parser;
		            this.pdfWriteValue(tpl.resources); // "n" will be changed
		        } else {
		            this.write('<</ProcSet [/PDF /Text /ImageB /ImageC /ImageI]');
   				if (this._res['tpl'] != undefined && this._res['tpl'] != null)
					if (this._res['tpl'][tplidx] != undefined) {
						var template:Object = this._res['tpl'][tplidx];
						//FONTS IN TEMPLATE
						if (template.fonts != undefined && template.fonts != null) {
			            	this.write('/Font <<');
			            	for each( var font:* in template.fonts ) 
			            		this.write('/F'+font.i+' '+font.n+' 0 R');
			            	this.write('>>');
			            }
						//IMAGES AND SUBTEMPLATES IN TEMPLATE
			        	if((template.images != undefined && template.images!=null) || 
			        	   (template.tpls != undefined && template.tpls!=null))
			        	{
			                this.write('/XObject <<');
			                if (template.images != undefined && template.images!=null) {
								for each ( var image:Object in template.images ) 
									this.write('/I'+image.i+' '+image.n+' 0 R');
			                }
			                if (template.tpls != undefined && template.tpls!=null) {
			                	var jdx:Number = template.length;
			                	var tpl2:Object;
			                    for(var j:Number=0;j<jdx;j++) {
			                    	tpl2 = template.tpls[j];
			                        this.write(this.tplprefix+j+' '+tpl2.n+' 0 R');
			                    }
			                }
			                this.write('>>');
			        	}
						//EXTGS IN TEMPLATE
						if (template.extgs != undefined && template.extgs != null) {
			            	this.write('/ExtGState <<');
			            	for each( var gs:String in template.extgs ) {
								this.write('/GS'+gs+' '+graphicStates[gs].n +' 0 R');
			            	}
			            	this.write('>>');
			            }
			  		}
		        	this.write('>>');
		        }
		
                if ( compress ) {
                	var stream:ByteArray = new ByteArray();
                    stream.writeMultiByte(tpl.buffer+"\n", "windows-1252" );
                    stream.compress(CompressionAlgorithm.ZLIB);
		        	this.write('/Length '+stream.length+' >>');
	                this.write('stream');
                    this.buffer.writeBytes( stream );
                    this.buffer.writeUTFBytes("\n");
                	this.write("endstream");
                } else {
		        	this.write('/Length '+tpl.buffer.length+' >>');
                    this.writeStream2(tpl.buffer.substr(0, tpl.buffer.length-1));
                }
	    		this.write('endobj');
		    }
		    
		    this.writeImportedObjects();
		}
		
		/**
		 * Rewritten to handle existing own defined objects
		 */
		protected function newObjE(obj_id:Number=NaN,onlynewObjE:Boolean=false):void {
		    if (isNaN(obj_id)) {
		        obj_id = ++this.n;
		    }
		
		    //Begin a new object
		    if (!onlynewObjE) {
		        this.offsets[obj_id] = this.buffer.length;
		        this.write(obj_id+' 0 obj');
		        this._current_obj_id = obj_id; // for later use with encryption
		    }
		}

		/**
		 * Writes a value
		 * Needed to rebuild the source document
		 *
		 * @param mixed value A PDF-Value. Structure of values see cases in this method
		 */
		protected function pdfWriteValue(value:Array):void {
		    switch (value[0]) {
		
				case PDFParser.PDF_TYPE_TOKEN :
		            this.straightWrite(value[1] + ' ');
					break;
			    case PDFParser.PDF_TYPE_NUMERIC :
				case PDFParser.PDF_TYPE_REAL :
		            if (value[1] is Number && value[1] != 0) {
					    this.straightWrite(sprintf('%F', value[1]).replace(/[\s|0]*$/,'').replace(/[\s|\.]*$/,'') + ' ');
					} else {
		    			this.straightWrite(value[1] + ' ');
					}
					break;
					
				case PDFParser.PDF_TYPE_ARRAY :
		
					// An array. Output the proper
					// structure and move on.
		
					this.straightWrite('[');
		            for (var i:Number = 0; i < value[1].length; i++) {
						this.pdfWriteValue(value[1][i]);
					}
		
					this.write(']');
					break;
		
				case PDFParser.PDF_TYPE_DICTIONARY :
		
					// A dictionary.
					this.straightWrite('<<');

					var v:Array;
					for (var k:* in value[1]) {
						v = value[1][k];
						this.straightWrite(k + ' ');
						this.pdfWriteValue(v);
					}		
		
					this.straightWrite('>>');
					break;
		
				case PDFParser.PDF_TYPE_OBJREF :
		
					// An indirect object reference
					// Fill the object stack if needed
					var cpfn:String = this.current_parser.filename;
					
					if (this._obj_stack[cpfn] == undefined)
						this._obj_stack[cpfn] = new Array(); 
					if (this._don_obj_stack[cpfn] == undefined)
						this._don_obj_stack[cpfn] = new Array(); 
					if (this._don_obj_stack[cpfn][value[1]] == undefined || this._don_obj_stack[cpfn][value[1]] == null) {
					    this.newObjE(NaN,true);
					    this._obj_stack[cpfn][value[1]] = [this.n, value];
		                this._don_obj_stack[cpfn][value[1]] = [this.n, value]; // Value is maybee obsolete!!!
		            }
		            var objid:Number = this._don_obj_stack[cpfn][value[1]][0];
		
					this.write(objid + ' 0 R');
					break;
		
				case PDFParser.PDF_TYPE_STRING :
		
					// A string.
		            this.straightWrite('('+value[1]+')');
		
					break;
		
				case PDFParser.PDF_TYPE_STREAM :
		
					// A stream. First, output the
					// stream dictionary, then the
					// stream data itself.
		            this.pdfWriteValue(value[1]);
		            this.writeStream2(value[2][1]);
					break;
		        case PDFParser.PDF_TYPE_HEX :
		            this.straightWrite('<'+value[1]+'>');
		            break;
		
		        case PDFParser.PDF_TYPE_BOOLEAN :
				    this.straightWrite(value[1] ? 'true ' : 'false ');
				    break;
		        
				case PDFParser.PDF_TYPE_NULL :
		            // The null object.
					this.straightWrite('null ');
					break;
			}
		}
		
		/**
		 * Modified so not each call will add a newline to the output.
		 */
		protected function straightWrite(content:*): void {
            if ( currentPage == null ) throw new Error ("No pages available, please call the addPage method first !");
            if ( state == 2 ) currentPage.content += content;
            else buffer.writeMultiByte( content, "windows-1252" );
	    }

	    /**
	     * rewritten to close opened parsers
	     *
	     */
		override protected function finishDocument():void {
			super.finishDocument();
			this.closeParsers();
		}
    
		/**
		 * close all files opened by parsers
		 */
		protected function closeParsers():Boolean {
		    if (this.state > 2 && this.parsers != null) {
		      	for (var k:* in this.parsers){
		      		(this.parsers[k] as PDFParser).closeFile();
		        	this.parsers[k] = null;
		        	delete this.parsers[k];
		        }
		        return true;
		    }
		    return false;
		}

	}
}