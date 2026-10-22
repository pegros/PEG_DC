/***
* @author P-E GROS
* @date   Oct 2026
* @description  LWC Component extending lightning-datatable with an 'inspectable' cell type (clickable cells) used by the SFPEG Data360 Query Tool.
* @see PEG_DC package (https://github.com/pegros/PEG_DC)
*
* Legal Notice
* 
* MIT License
* 
* Copyright (c) 2026 pegros
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
***/

import LightningDatatable from 'lightning/datatable';
import inspectableCellTemplate from './inspectableCell.html';

export default class SfpegData360DatatableCmp extends LightningDatatable {

    // 'inspectable' cells display a formatted value (as per displayType: text, number, date-local or date)
    // and dispatch a 'cellinspect' event (with column label and raw value) when clicked,
    // their text being wrapped or truncated as per wrapText (column 'Wrap text' / 'Clip text' header action
    // to be propagated by the parent component, the datatable wrapText not being reliably passed to custom cells)
    static customTypes = {
        inspectable: {
            template: inspectableCellTemplate,
            standardCellLayout: true,
            typeAttributes: ['label', 'displayType', 'wrapText']
        }
    };
}
