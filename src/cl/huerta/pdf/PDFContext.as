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

package cl.huerta.pdf
{
	import flash.utils.ByteArray;
	import flash.utils.getDefinitionByName;
	
	public class PDFContext
	{
	    /**
	     * Modi
	     *
	     * @var integer 0 = file | 1 = string
	     */
	    protected var _mode:Number = 0;
	    
		protected var file:*;
		public var bbuffer:ByteArray;
		public var buffer:String;
		public var offset:Number;
		public var length:Number;
		
		protected var _stream:*;
		public function get stream():* {
			return this._stream;
		}
		
		public var stack:Array;

		// Constructor
		public function PDFContext(f:*)
		{
			this.file = f;
			var className:String = flash.utils.getQualifiedClassName(f);
			if (f is String)
				this._mode = 1;
			else if (className == "flash.filesystem.File") {
				var streamClass:Class = getDefinitionByName("flash.filesystem.FileStream") as Class;
				this._stream = new streamClass();
				this._stream.open(f, "read");
			} else 
				this._stream = f;
			this.bbuffer = new ByteArray();
			this.reset();
		}
	
		// Optionally move the file
		// pointer to a new location
		// and reset the buffered data
		public function reset(pos:Number = NaN, l:Number = 100):void {
		    if (this._mode == 0) {
	        	if (!isNaN(pos))
	        		this._stream.position = pos;
	    		else
	    			pos = this._stream.position;
        		this.bbuffer.clear();
	    		if (l>0) {
	    			this.buffer = _stream.readMultiByte(Math.min(this.stream.bytesAvailable,l), "windows-1252");
	        		this._stream.position = pos;
		    		_stream.readBytes(this.bbuffer, 0, Math.min(this.stream.bytesAvailable,l));
	    		}
		    	else {
	    			this.buffer = '';
		    	}
	    		this.length = this.bbuffer.length;
	    		if (this.length < l)
	                this.increaseLength(l - this.length);
		    } else {
		        this.buffer = this.file;
		        this.bbuffer.clear();
		        this.bbuffer.writeUTF(this.buffer);
		        this.length = this.buffer.length;
		    }
			this.offset = 0;
			this.stack = new Array();
		}
	
		// Make sure that there is at least one
		// character beyond the current offset in
		// the buffer to prevent the tokenizer
		// from attempting to access data that does
		// not exist
		public function ensureContent():Boolean {
			if (this.offset >= this.length - 1) {
				return this.increaseLength();
			} else {
				return true;
			}
		}
	
		// Forcefully read more data into the buffer
		public function increaseLength(l:Number=100):Boolean {
			if (this._mode == 0 && this._stream.bytesAvailable == 0) {
				return false;
			} else if (this._mode == 0) {
			    var totalLength:Number = this.length + Math.min(l, this._stream.bytesAvailable);
			    do {
	    			var pos:Number = this._stream.position;
	    			this.buffer += _stream.readMultiByte((totalLength-this.length), "windows-1252");
	        		this._stream.position = pos;
		    		_stream.readBytes(this.bbuffer, this.length, Math.min(this.stream.bytesAvailable,l));
	                this.length = this.bbuffer.length;
	            } while ((this.length != totalLength) && (this._stream.bytesAvailable > 0));
				
				return true;
			} else {
		        return false;
			}
		}

	}
}