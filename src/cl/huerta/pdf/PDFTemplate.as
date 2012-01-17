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
	
	import org.alivepdf.annotations.Annotation;
	import org.alivepdf.colors.RGBColor;
	import org.alivepdf.fonts.IFont;
	import org.alivepdf.layout.Resize;
	import org.alivepdf.layout.Size;
	import org.alivepdf.links.ILink;
	import org.alivepdf.pages.Page;
	import org.alivepdf.pdf.PDF;
	import org.alivepdf.tools.sprintf;

	public class PDFTemplate extends PDF
	{
	
	    /**
	     * Array of Tpl-Data
	     * @var array
	     */
	    protected var tpls:Array = new Array();
	
	    /**
	     * Current Template-ID
	     * @var int
	     */
	    protected var tpl:Number = 0;
	    
	    /**
	     * "In Template"-Flag
	     * @var boolean
	     */
	    protected var _intpl:Boolean = false;
	    
	    /**
	     * Nameprefix of Templates used in Resources-Dictonary
	     * @var string A String defining the Prefix used as Template-Object-Names. Have to beginn with an /
	     */
	    protected var tplprefix:String = "/TPL";
	
	    /**
	     * Resources used By Templates and Pages
	     * @var dictionary
	     */
	    protected var _res:Dictionary = new Dictionary();
	    
	    /**
	     * Last used Template data
	     *
	     * @var object
	     */
	    protected var lastUsedTemplateData:Object = null;

		public function PDFTemplate(orientation:String='Portrait', unit:String='Mm', autoPageBreak:Boolean=true, pageSize:Size=null, rotation:int=0)
		{
			super(orientation, unit, autoPageBreak, pageSize, rotation);
		}
		
	    /**
	     * Start a Template
	     *
	     * This method starts a template. You can give own coordinates to build an own sized
	     * Template. Pay attention, that the margins are adapted to the new templatesize.
	     * If you want to write outside the template, for example to build a clipped Template,
	     * you have to set the Margins and "Cursor"-Position manual after beginTemplate-Call.
	     *
	     * If no parameter is given, the template uses the current page-size.
	     * The Method returns an ID of the current Template. This ID is used later for using this template.
	     * Warning: A created Template is used in PDF at all events. Still if you don't use it after creation!
	     *
	     * @param int $x The x-coordinate given in user-unit
	     * @param int $y The y-coordinate given in user-unit
	     * @param int $w The width given in user-unit
	     * @param int $h The height given in user-unit
	     * @return int The ID of new created Template
	     */
	    public function beginTemplate(x:Number=0, y:Number=0, w:Number=-1, h:Number=-1):Number {
            if ( this.currentPage == null ) throw new Error ("No pages available, please call the addPage method first !");
	
			if (w == -1)
				w = this.currentPage.w;
			if (h == -1)
				h = this.currentPage.h;
	
	        // Save settings
	        var template:Object = this.tpls[this.tpl];
	        if (template == null)
	        	template = new Object();

			template.o_x = this.currentX;
			template.o_y = this.currentY;
			template.o_AutoPageBreak = this.autoPageBreak;
			template.o_bMargin = this.bottomMargin;
			template.o_tMargin = this.topMargin;
			template.o_lMargin = this.leftMargin;
			template.o_rMargin = this.rightMargin;
			template.o_h = this.currentPage.h;
			template.o_w = this.currentPage.w;
			template.buffer = '';
			template.x = x;
			template.y = y;
			template.w = w;
			template.h = h;
			
			this.tpls[++this.tpl] = template;
	
	        this.autoPageBreak = false;
	        
	        // Define own high and width to calculate possitions correct
	        this.currentPage.h = h;
	        this.currentPage.w = w;
	
	        this._intpl = true;
	        this.setXY(x+this.leftMargin, y+this.topMargin);
	        this.setRightMargin(this.currentPage.w-w+this.rightMargin);
	
	        return this.tpl;
	    }

	    /**
	     * End Template
	     *
	     * This method ends a template and reset initiated variables on beginTemplate.
	     *
	     * @return mixed If a template is opened, the ID is returned. If not a false is returned.
	     */
	    public function endTemplate():* {
	        if (this._intpl) {
	            this._intpl = false;
	            
	            var template:Object = this.tpls[this.tpl];
	            this.setXY(template.o_x, template.o_y);
	            this.topMargin = template.o_tMargin;
	            this.leftMargin = template.o_lMargin;
	            this.rightMargin = template.o_rMargin;
	            this.currentPage.h = template.o_h;
	            this.currentPage.w = template.o_w;
	            this.setAutoPageBreak(template.o_AutoPageBreak, template.o_bMargin);
	            
	            return this.tpl;
	        } else {
	            return false;
	        }
	    }

		/**
		 * Use a Template in current Page or other Template
		 *
		 * You can use a template in a page or in another template.
		 * You can give the used template a new size like you use the Image()-method.
		 * All parameters are optional. The width or height is calculated automaticaly
		 * if one is given. If no parameter is given the origin size as defined in
		 * beginTemplate() is used.
		 * The calculated or used width and height are returned as an array.
		 *
		 * @param int tplidx A valid template-Id
		 * @param int $_x The x-position
		 * @param int $_y The y-position
		 * @param int $_w The new width of the template
		 * @param int $_h The new height of the template
		 * @retrun array The height and width of the template
		 */
	    public function useTemplate(tplidx:Number, _x:Number=0, _y:Number=0, _w:Number=0, _h:Number=0, adjustPageSize:Boolean=false):Object {
            if ( currentPage == null ) throw new Error ("No pages available, please call the addPage method first !");
			
			if (this.tpls[tplidx] == null)
				throw new Error("Template does not exist!");
			    
			if (this._intpl) {
				if (this._res['tpl'] == undefined || this._res['tpl'] == null)
					this._res['tpl'] = new Array();
				if (this._res['tpl'][this.tpl] == undefined)
					this._res['tpl'][this.tpl] = new Object();
				if (this._res['tpl'][this.tpl].tpls == undefined || this._res['tpl'][this.tpl].tpls == null)
					this._res['tpl'][this.tpl].tpls = new Array();

				this._res['tpl'][this.tpl].tpls[tplidx] = this.tpls[tplidx];
			}
	        
			var tpl:Object = this.tpls[tplidx];
			var w:Number = tpl.w;
			var h:Number = tpl.h;
			
			_x += tpl.x;
			_y += tpl.y;
			
			var wh:* = this.getTemplateSize(tplidx, _w, _h);
			_w = wh.w;
			_h = wh.h;
						
			var tData:Object = new Object();
			tData.x = this.currentX;
			tData.y = this.currentY;
			tData.w = _w;
			tData.h = _h;
			tData.scaleX = (_w/w);
			tData.scaleY = (_h/h);
			tData.tx = _x;
			tData.ty =  (this.currentPage.h-_y-_h);
			tData.lty = (this.currentPage.h-_y-_h) - (this.currentPage.h-h) * (_h/h);
	        
	        this.write(sprintf("q %.4F 0 0 %.4F %.4F %.4F cm", tData.scaleX, tData.scaleY, tData.tx*this.k, tData.ty*this.k)); // Translate 
	        this.write(sprintf('%s%d Do Q', this.tplprefix, tplidx));
	
	        this.lastUsedTemplateData = tData;
	        
	        return {w : _w, h : _h};
	    }
	
	    /**
	     * Get The calculated Size of a Template
	     *
	     * If one size is given, this method calculates the other one.
	     *
	     * @param int tplidx A valid template-Id
	     * @param int $_w The width of the template
	     * @param int $_h The height of the template
	     * @return array The height and width of the template
	     */
	    public function getTemplateSize(tplidx:Number, _w:Number=0, _h:Number=0):* {
	        if (this.tpls[tplidx] == null)
	            return false;
	
	        var tpl:Object = this.tpls[tplidx];
	        var w:Number = tpl.w;
	        var h:Number = tpl.h;
	        
	        if (_w == 0 && _h == 0) {
	            _w = w;
	            _h = h;
	        }
	
	    	if(_w==0)
	    		_w = _h*w/h;
	    	if(_h==0)
	    		_h = _w*h/w;
	    		
	        return {w : _w, h : _h};
	    }

	    /**
	     * See AlivePDF Documentation ;-)
	     */
		override public function setFont ( font:IFont, size:int=12, underlined:Boolean=false ):void {
	        /**
	         * force the resetting of font changes in a template
	         */
	        if (this._intpl)
	            this.fontFamily = '';
	            
	        super.setFont(font, size, underlined);
	       
	        var fontkey:String = this.fontFamily + this.fontStyle;
	        
	        if (this._intpl) {
				if (this._res['tpl'] == undefined || this._res['tpl'] == null)
					this._res['tpl'] = new Array();
				if (this._res['tpl'][this.tpl] == undefined)
					this._res['tpl'][this.tpl] = new Object();
				if (this._res['tpl'][this.tpl].fonts == undefined || this._res['tpl'][this.tpl].fonts == null)
					this._res['tpl'][this.tpl].fonts = new Dictionary();

	            this._res['tpl'][this.tpl].fonts[fontkey] = this.fonts[fontkey];
	        } else {
				if (this._res['page'] == undefined || this._res['tpl'] == null)
					this._res['page'] = new Array();
				if (this._res['page'][this.currentPage.number] == undefined)
					this._res['page'][this.currentPage.number] = new Object();
				if (this._res['page'][this.currentPage.number].fonts == undefined || this._res['tpl'][this.currentPage.number].fonts == null)
					this._res['page'][this.currentPage.number].fonts = new Dictionary();

	            this._res['page'][this.currentPage.number].fonts[fontkey] = this.fonts[fontkey];
	        }
	    }
	    
	    /**
	     * See AlivePDF Documentation ;-)
	     */
		override public function addImageStream ( imageBytes:ByteArray, colorSpace:String, resizeMode:Resize=null, x:Number=0, y:Number=0, width:Number=0, height:Number=0, rotation:Number=0, alpha:Number=1, blendMode:String="Normal", link:ILink=null ):void {
	    	super.addImageStream(imageBytes, colorSpace, resizeMode, x, y, width, height, rotation, alpha, blendMode, link);
	        if (this._intpl) {
				if (this._res['tpl'] == undefined || this._res['tpl'] == null)
					this._res['tpl'] = new Array();
				if (this._res['tpl'][this.tpl] == undefined)
					this._res['tpl'][this.tpl] = new Object();
				if (this._res['tpl'][this.tpl].images == undefined || this._res['tpl'][this.tpl].tpls == null)
					this._res['tpl'][this.tpl].images = new Dictionary();

	            this._res['tpl'][this.tpl].images[imageBytes] = this.streamDictionary[imageBytes];

				if (this._res['tpl'] == undefined || this._res['tpl'] == null)
					this._res['tpl'] = new Array();
				if (this._res['tpl'][this.tpl] == undefined)
					this._res['tpl'][this.tpl] = new Object();
				if (this._res['tpl'][this.tpl].extgs == undefined || this._res['tpl'][this.tpl].extgs == null)
					this._res['tpl'][this.tpl].extgs = new Array();
					
				this._res['tpl'][this.tpl].extgs.push(this.graphicStates.length-1);
	        } else {
				if (this._res['page'] == undefined || this._res['tpl'] == null)
					this._res['page'] = new Array();
				if (this._res['page'][this.currentPage.number] == undefined)
					this._res['page'][this.currentPage.number] = new Object();
				if (this._res['page'][this.currentPage.number].images == undefined || this._res['tpl'][this.currentPage.number].images == null)
					this._res['page'][this.currentPage.number].images = new Dictionary();

	            this._res['page'][this.currentPage.number].images[imageBytes] = this.streamDictionary[imageBytes];
	        }
	    }
	    
	    /**
	     * See AlivePDF Documentation ;-)
	     *
	     * AddPage is not available when you're "in" a template.
	     */
	    override public function addPage(page:Page = null):Page  {
	        if (this._intpl)
	            throw new Error('Adding pages in templates isn\'t possible!');
	        return super.addPage(page);
    	}
    	
//	    /**
//	     * Preserve adding Links in Templates ...won't work
//	     */
//		override public function addTextNote ( x:Number, y:Number, width:Number, height:Number, text:String="A note !" ):void {
//			if (this._intpl)
//				throw new Error('Using annotations in templates aren\'t possible');
//			super.addTextNote(x,y,width,height,text);
//		}
//		
//		override public function addStampNote ( style:String, x:Number, y:Number, width:Number, height:Number ):void {
//			if (this._intpl)
//				throw new Error('Using annotations in templates aren\'t possible');
//			super.addStampNote(style,x,y,width,height);
//		}

		override public function addAnnotation ( annotation:Annotation ):void {
			if (this._intpl)
				throw new Error('Using annotations in templates aren\'t possible');
			super.addAnnotation(annotation);
		}
		
	    override public function addLink( x:Number, y:Number, width:Number, height:Number, link:ILink, highlight:String="I" ):void {
			if (this._intpl)
	            throw new Error('Using links in templates aren\'t possible!');
	        super.addLink(x,y,width,height,link,highlight);
	    }
	    
	    override public function addBookmark( text:String, level:int=0, y:Number=-1, color:RGBColor=null ):void {
	        if (this._intpl)
	            throw new Error('Using bookmarks in templates aren\'t possible!');
	        super.addBookmark(text,level,y,color);
	    }

	    /**
	     * Private Method that writes the form xobjects
	     */
	    protected function writeFormXObjects():void {
			var compress:Boolean = (this.currentPage in this.compressedPages);
	        var filter:String=(compress) ? '/Filter /FlateDecode ' : '';
			var idx:Number = this.tpls.length;
			var tplidx:Number = 0;
			var tpl:Object;
	        for(tplidx=1;tplidx<idx;tplidx++) {
	        	tpl = this.tpls[tplidx];
	    		this.newObj();
	    		this.tpls[tplidx].n = this.n;
	    		this.write('<<'+filter+'/Type /XObject');
	            this.write('/Subtype /Form');
	            this.write('/FormType 1');
	            this.write(sprintf('/BBox [%.2F %.2F %.2F %.2F]',
	                // llx
	                tpl.x,
	                // lly
	                -tpl.y,
	                // urx
	                (tpl.w+tpl.x)*this.k,
	                // ury
	                (tpl.h-tpl.y)*this.k
	            ));
	            
	            if (tpl.x != 0 || tpl.y != 0) {
	                this.write(sprintf('/Matrix [1 0 0 1 %.5F %.5F]',
	                     -tpl.x*this.k*2, tpl.y*this.k*2
	                ));
	            }
	            
	            this.write('/Resources ');
	
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
                    this.writeStream(tpl.buffer.substr(0, tpl.buffer.length-1));
                }
	    		this.write('endobj');
	        }
	    }

	    /**
	     * Overwritten to add _putformxobjects() after _putimages()
	     *
	     */
		override protected function insertImages ():void {
		    super.insertImages();
		    this.writeFormXObjects();
		}
		
	    override protected function writeXObjectDictionary():void {
	        super.writeXObjectDictionary();
	        
	        if (this.tpls.length > 0) {
	        	var idx:Number = this.tpls.length;
	        	var tpl:Object;
	            for (var i:Number=1; i<idx;i++) {
	            	tpl = this.tpls[i];
	                this.write(sprintf('%s%d %d 0 R', this.tplprefix, i, tpl.n));
	            }
	        }
    	}

	    /**
	     * Private Method
	     */
	             
        protected function writeStream2(stream:*):void {
            write('stream');
            if (stream is String)
	            write(stream);
	        else if (stream is ByteArray) {
	        	buffer.writeBytes(stream);
	        	buffer.writeUTF("\n");
	        }
            write('endstream');
        }
	     
        override protected function write( content:String ):void {
            if ( currentPage == null ) throw new Error ("No pages available, please call the addPage method first !");
            if ( state == 2 && this._intpl) this.tpls[this.tpl].buffer += content+"\n"; //write everything to internal template!!!
            else super.write(content);
        }

	}

}