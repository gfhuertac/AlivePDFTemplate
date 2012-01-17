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

package cl.huerta.pdf.decoders
{
	import flash.utils.ByteArray;
	
	
	public class LZWDecode implements Decoder
	{
	    protected var sTable:Array = new Array();
	    protected var data:String = null;
	    protected var dataLength:Number = 0;
	    protected var tIdx:Number;
	    protected var bitsToGet:Number = 9;
	    protected var bytePointer:Number;
	    protected var bitPointer:*;
	    protected var nextData:* = 0;
	    protected var nextBits:* = 0;
	    protected var andTable:Array = [511, 1023, 2047, 4095];

		public function LZWDecode()
		{
		}
		
		public function decode(in_:*):String {
			if (in_ is ByteArray)
				return this._decode(in_.readUTFBytes(in_.length));
			else if (in_ is String)
				return this._decode(in_);
			return null;
		}
		
	    /**
	     * Method to decode LZW compressed data.
	     *
	     * @param string data    The compressed data.
	     */
		public function _decode(in_:String):String {
	
	        if(data[0] == 0x00 && data[1] == 0x01) {
	            throw new Error('LZW flavour not supported.');
	        }
	
	        this.initsTable();
	
	        this.data = data;
	        this.dataLength = data.length;
	
	        // Initialize pointers
	        this.bytePointer = 0;
	        this.bitPointer = 0;
	
	        this.nextData = 0;
	        this.nextBits = 0;
	
	        var oldCode:Number = 0;
	
	        var string:String = '';
	        var uncompData:String = '';
	
			var code:Number;
	        while ((code = this.getNextCode()) != 257) {
	            if (code == 256) {
	                this.initsTable();
	                code = this.getNextCode();
	
	                if (code == 257) {
	                    break;
	                }
	
	                uncompData += this.sTable[code];
	                oldCode = code;
	
	            } else {
	
	                if (code < this.tIdx) {
	                    string = this.sTable[code];
	                    uncompData += string;
	
	                    this.addStringToTable(this.sTable[oldCode], string[0]);
	                    oldCode = code;
	                } else {
	                    string = this.sTable[oldCode];
	                    string = string+string[0];
	                    uncompData += string;
	
	                    this.addStringToTable(string);
	                    oldCode = code;
	                }
	            }
	        }
	        
	        return uncompData;
	    }

	    /**
	     * Initialize the string table.
	     */
	    protected function initsTable():void {
	        this.sTable = new Array();
	
	        for (var i:Number = 0; i < 256; i++)
	            this.sTable[i] = String.fromCharCode(i);
	
	        this.tIdx = 258;
	        this.bitsToGet = 9;
	    }
	
	    /**
	     * Add a new string to the string table.
	     */
	    protected function addStringToTable (oldString:String, newString:String=''):void {
	        var string:String = oldString + newString;
	
	        // Add this new String to the table
	        this.sTable[this.tIdx++] = string;
	
	        if (this.tIdx == 511) {
	            this.bitsToGet = 10;
	        } else if (this.tIdx == 1023) {
	            this.bitsToGet = 11;
	        } else if (this.tIdx == 2047) {
	            this.bitsToGet = 12;
	        }
	    }

	    // Returns the next 9, 10, 11 or 12 bits
	    protected function getNextCode():Number {
	        if (this.bytePointer == this.dataLength) {
	            return 257;
	        }
	
	        this.nextData = (this.nextData << 8) | ((this.data[this.bytePointer++]).charCodeAt() & 0xff);
	        this.nextBits += 8;
	
	        if (this.nextBits < this.bitsToGet) {
	            this.nextData = (this.nextData << 8) | ((this.data[this.bytePointer++]).charCodeAt() & 0xff);
	            this.nextBits += 8;
	        }
	
	        var code:Number = (this.nextData >> (this.nextBits - this.bitsToGet)) & this.andTable[this.bitsToGet-9];
	        this.nextBits -= this.bitsToGet;
	
	        return code;
	    }    
	}
}