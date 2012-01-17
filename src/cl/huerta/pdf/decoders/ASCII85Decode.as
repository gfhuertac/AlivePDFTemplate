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
	
	
	public final class ASCII85Decode implements Decoder
	{
		public static const	ORD_u:Number        = "u".charCodeAt();
		public static const ORD_z:Number        = "z".charCodeAt();
		public static const	ORD_exclmark:Number = "!".charCodeAt();
		public static const	ORD_tilde:Number    = "~".charCodeAt();
		
		public static const CHR_zero:String     = String.fromCharCode(0);
		
		public static const RE_empty:RegExp     = /^\s$/;
		
		public function ASCII85Decode()
		{
		}
		
		public function decode(in_:*):String {
			if (in_ is ByteArray)
				return this._decode(in_.readUTFBytes(in_.length));
			else if (in_ is String)
				return this._decode(in_);
			return null;
		}
		
		public function _decode(in_:String):String {
	        var out:String = '';
	        var state:Number = 0;
	        var chn:Array = new Array();
	        
	        if (in_.substr(0,2)=='<~')
	        	in_ = in_.substr(2);
	        
	        var l:Number = in_.length;
		    var ch:int;
	        for (var k:Number = 0; k < l; ++k) {
	            ch = in_.charCodeAt(k) & 0xff;
	            
	            if (ch == ORD_tilde) {
	                break;
	            }
	            if (RE_empty.test(in_.charAt(k))) {
	                continue;
	            }
	            if (ch == ORD_z && state == 0) {
	                out += CHR_zero+CHR_zero+CHR_zero+CHR_zero;
	                continue;
	            }
	            if (ch < ORD_exclmark || ch > ORD_u) {
	                throw new Error('Illegal character in ASCII85Decode.');
	            }
	            
	            chn[state++] = ch - ORD_exclmark;
	            
	            if (state == 5) {
	                state = 0;
	                var r:Number = 0;
	                for (var j:Number = 0; j < 5; ++j)
	                    r = r * 85 + chn[j];
	                out += String.fromCharCode(r >> 24 & 0xff);
	                out += String.fromCharCode(r >> 16 & 0xff);
	                out += String.fromCharCode(r >> 8 & 0xff);
	                out += String.fromCharCode(r & 0xff);
	            }
	        }
			 
			r = 0;
			
			if (state == 1)
			    throw new Error('Illegal length in ASCII85Decode.');
			if (state == 2) {
			    r = chn[0] * 85 * 85 * 85 * 85 + (chn[1]+1) * 85 * 85 * 85;
			    out += String.fromCharCode(r >> 24 & 0xff);
			}
			else if (state == 3) {
			    r = chn[0] * 85 * 85 * 85 * 85 + chn[1] * 85 * 85 * 85  + (chn[2]+1) * 85 * 85;
			    out += String.fromCharCode(r >> 24 & 0xff);
			    out += String.fromCharCode(r >> 16 & 0xff);
			}
			else if (state == 4) {
			    r = chn[0] * 85 * 85 * 85 * 85 + chn[1] * 85 * 85 * 85  + chn[2] * 85 * 85  + (chn[3]+1) * 85 ;
			    out += String.fromCharCode(r >> 24 & 0xff);
			    out += String.fromCharCode(r >> 16 & 0xff);
			    out += String.fromCharCode(r >> 8 & 0xff);
			}

        
	        return out;
		}
		

	}
}