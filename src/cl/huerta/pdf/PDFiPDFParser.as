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
	import cl.huerta.pdf.decoders.ASCII85Decode;
	import cl.huerta.pdf.decoders.Decoder;
	import cl.huerta.pdf.decoders.LZWDecode;
	
	import flash.utils.ByteArray;
	import flash.utils.CompressionAlgorithm;
	import flash.utils.Dictionary;
	
	import org.alivepdf.tools.sprintf;
	
	public class PDFiPDFParser extends PDFParser
	{
		protected const decoders:Object = {ASCII85Decode:new ASCII85Decode(), LZWDecode:new LZWDecode()};
		
	    /**
	     * Pages
	     * Index beginns at 0
	     *
	     * @var array
	     */
	    public var pages:Array = new Array();
	    
	    /**
	     * Page count
	     * @var integer
	     */
	    protected var page_count:Number;
	    public function getPageCount(): Number {
	    	return page_count;
	    }
	    
	    /**
	     * actual page number
	     * @var integer
	     */
	    protected var pageno:Number;
	    public function getPageNo(): Number {
	        return this.pageno;
	    }
	    public function setPageNo(newValue_:Number): void {
	        newValue_ -= 1;
	
	        if (newValue_ < 0 || newValue_ >= this.getPageCount()) {
	            throw new Error('Pagenumber is wrong!');
	        }
	
	        this.pageno = newValue_;
	    }
	    
	    /**
	     * PDF Version of imported Document
	     * @var string
	     */
	    //protected var pdfVersion:String;
	    
	    /**
	     * FPDI Reference
	     * @var object
	     */
	    protected var fpdi:PDFi;
	    
	    /**
	     * Available BoxTypes
	     *
	     * @var array
	     */
	    public static const availableBoxes:Array = ['/MediaBox', '/CropBox', '/BleedBox', '/TrimBox', '/ArtBox'];

		public function PDFiPDFParser(filename_:String, fpdi_:PDFi = null)
		{
			this.fpdi = fpdi_;
			
			super(filename_);
			
			// resolve Pages-Dictonary
			var pages:Array = this.pdfResolveObject(this._c, this.root[1][1]['/Pages']);
			
			// Read pages
			this.readPages(this._c, pages, this.pages);
			
			// count pages;
			this.page_count = this.pages.length;
		}
		
		/**
		 * Get page-resources from current page
		 *
		 * @return array or false
		 */
		public function getPageResources():* {
		    return this._getPageResources(this.pages[this.pageno]); 
		}
		
		/**
		 * Get page-resources from /Page
		 *
		 * @param array $obj Array of pdf-data
		 */
		protected function _getPageResources (obj:Array):* { // $obj = /Page
			obj = this.pdfResolveObject(this._c, obj);
			var res:Array;
		    // If the current object has a resources
			// dictionary associated with it, we use
			// it. Otherwise, we move back to its
			// parent object.
		    if (obj[1][1]['/Resources'] != undefined && obj[1][1]['/Resources'] != null) {
				res = this.pdfResolveObject(this._c, obj[1][1]['/Resources']);
				if (res[0] == PDF_TYPE_OBJECT)
		            return res[1];
		        return res;
			} else {
				if (obj[1][1]['/Parent'] == undefined || obj[1][1]['/Parent'] == null) {
					return false;
				} else {
		            res = this._getPageResources(obj[1][1]['/Parent']);
		            if (res[0] == PDF_TYPE_OBJECT)
		                return res[1];
		            return res;
				}
			}
		}

		
		/**
		 * Get content of current page
		 *
		 * If more /Contents is an array, the streams are concated
		 *
		 * @return string
		 */
		public function getContent():String {
		    var buffer:String = '';
		    
		    if (this.pages[this.pageno][1][1]['/Contents'] != undefined && this.pages[this.pageno][1][1]['/Contents'] != null) {
		        var contents:* = this._getPageContent(this.pages[this.pageno][1][1]['/Contents']);
		        for each(var tmp_content:* in contents) {
		            buffer += this._rebuildContentStream(tmp_content)+' ';
		        }
		    }
		    
		    return buffer;
		}
		
		/**
		 * Resolve all content-objects
		 *
		 * @param array $content_ref
		 * @return array
		 */
		protected function _getPageContent(content_ref:Array):* {
		    var contents:Array = new Array();
		    
		    if (content_ref[0] == PDF_TYPE_OBJREF) {
		        var content:* = this.pdfResolveObject(this._c, content_ref);
		        if (content[1][0] == PDF_TYPE_ARRAY) {
		            contents = this._getPageContent(content[1]);
		        } else {
		            contents.push(content);
		        }
		    } else if (content_ref[0] == PDF_TYPE_ARRAY) {
		        for each (var tmp_content_ref:* in content_ref[1]) {
		            contents = contents.concat(this._getPageContent(tmp_content_ref));
		        }
		    }
		
		    return contents;
		}
		
		
		/**
		 * Rebuild content-streams
		 *
		 * @param array $obj
		 * @return string
		 */
		protected function _rebuildContentStream(obj:Array):String {
		    var filters:Array = new Array();
		    var _filter:Array;
		    if (obj[1][1]['/Filter'] != undefined && obj[1][1]['/Filter'] != null) {
		        _filter = obj[1][1]['/Filter'];
		
		        if (_filter[0] == PDF_TYPE_TOKEN) {
		            filters.push(_filter);
		        } else if (_filter[0] == PDF_TYPE_ARRAY) {
		            filters = _filter[1];
		        }
		    }
		
		    var stream:* = obj[2][1];// changed ... is it OK?
		
		    for each (_filter in filters) {
		        switch (_filter[1]) {
		            case '/FlateDecode':
		            	if (stream != null && stream.length > 0) {
		            		var ba:ByteArray;
		            		if (stream is ByteArray)
		            			ba = stream;
		            		else {
							    ba = new ByteArray();
							    ba.writeUTFBytes(stream);
		            		}
						    ba.position = 0;
		            		ba.uncompress(CompressionAlgorithm.ZLIB);
		            		stream = ba.readUTFBytes(ba.length);
		            	} else
		            		stream = '';
		            break;
		            case null:
		                stream = stream;
		            break;
		            default:
		            	var filterNames:Array = (_filter[1] as String).match(/^\/[a-z85]*$/i);
		            	if (filterNames != null && filterNames.length > 0)
		            	{
		                    if (decoders[filterName] != undefined) {
			            		var filterName:String = (_filter[1] as String).substr(1);
			                    stream.writeUTFBytes((decoders[filterName] as Decoder).decode(stream));
			                } else
			                	throw new Error(sprintf('Unsupported Filter: %s',_filter[1]));
		                } else {
		                    throw new Error(sprintf('Unsupported Filter: %s',_filter[1]));
		                }
		        }
		    }
		    
		    return stream;
		}

		/**
		 * Get a Box from a page
		 * Arrayformat is same as used by fpdf_tpl
		 *
		 * @param array $page a /Page
		 * @param string $box_index Type of Box @see $availableBoxes
		 * @return array
		 */
		public function getPageBox(page:Array, box_index:String):* {
		    page = this.pdfResolveObject(this._c,page); //TODO: should we copy it?
		    var box:Array = null;
		    if (page[1][1][box_index] != undefined && page[1][1][box_index] != null)
		        box = page[1][1][box_index];
		    
		    if (box != null && box[0] == PDF_TYPE_OBJREF) {
		        var tmp_box:Array = this.pdfResolveObject(this._c,box);
		        box = tmp_box[1];
		    }
		        
		    if (box != null && box[0] == PDF_TYPE_ARRAY) {
		        var b:* = box[1];
		        return {x : b[0][1]/this.fpdi._k,
		                y : b[1][1]/this.fpdi._k,
		                w : Math.abs(b[0][1]-b[2][1])/this.fpdi._k,
		                h : Math.abs(b[1][1]-b[3][1])/this.fpdi._k,
		                llx : b[0][1]/this.fpdi._k,
		                lly : b[1][1]/this.fpdi._k,
		                urx : b[2][1]/this.fpdi._k,
		                ury : b[3][1]/this.fpdi._k
		                };
		    } else if (page[1][1]['/Parent'] == undefined || page[1][1]['/Parent'] == null) {
		        return false;
		    } else {
		        return this.getPageBox(this.pdfResolveObject(this._c, page[1][1]['/Parent']), box_index);
		    }
		}
		
		public function getPageBoxes(pageno:Number):Dictionary {
		    return this._getPageBoxes(this.pages[pageno-1]);
		}
		
		/**
		 * Get all Boxes from /Page
		 *
		 * @param array a /Page
		 * @return dictionary
		 */
		protected function _getPageBoxes(page:Array):Dictionary {
		    var boxes:Dictionary = new Dictionary();
		
		    for each(var box:String in availableBoxes) {
		    	var _box:* = this.getPageBox(page,box);
		        if (_box !== false) {
		            boxes[box] = _box;
		        }
		    }
		
		    return boxes;
		}


		/**
		 * Get the page rotation by pageno
		 *
		 * @param integer $pageno
		 * @return array
		 */
		public function getPageRotation(pageno:Number): * {
		    return this._getPageRotation(this.pages[pageno-1]);
		}
		
		protected function _getPageRotation (obj:Array):* { // $obj = /Page
			obj = this.pdfResolveObject(this._c, obj);
			var res:*;
			if (obj[1][1]['/Rotate'] != undefined && obj[1][1]['/Rotate'] != null) {
				res = this.pdfResolveObject(this._c, obj[1][1]['/Rotate']);
				if (res[0] == PDF_TYPE_OBJECT)
		            return res[1];
		        return res;
			} else {
				if (obj[1][1]['/Parent'] == undefined || obj[1][1]['/Parent'] == null) {
					return false;
				} else {
		            res = this._getPageRotation(obj[1][1]['/Parent']);
		            if (res !== false)
			            if (res[0] == PDF_TYPE_OBJECT)
			                return res[1];
		            return res;
				}
			}
		}
	    
	    /**
	     * Read all /Page(es)
	     *
	     * @param object pdf_context
	     * @param array /Pages
	     * @param array the result-array
	     */
	    protected function readPages (c:PDFContext, pages:Array, result:Array):void {
	        // Get the kids dictionary
	    	var kids:* = this.pdfResolveObject(c, pages[1][1]['/Kids']);
	
	        if (!(kids is Array))
	            throw new Error('Cannot find /Kids in current /Page-Dictionary');
	        for each (var v:Array in kids[1]) {
	    		var pg:Array = this.pdfResolveObject(c, v);
	            if (pg[1][1]['/Type'][1] === '/Pages') {
	                // If one of the kids is an embedded
	    			// /Pages array, resolve it as well.
	                this.readPages (c, pg, result);
	    		} else {
	    			result.push(pg);
	    		}
	    	}
	    }
	    
	    /**
	     * Get PDF-Version
	     *
	     * And reset the PDF Version used in FPDI if needed
	     */
	    override protected function getPDFVersion():String {
	        super.getPDFVersion();
	        this.fpdi._pdfVersion = (this.fpdi._pdfVersion > this.pdfVersion) ? this.fpdi._pdfVersion : this.pdfVersion;
	        return this.pdfVersion;
	    }
	}
}