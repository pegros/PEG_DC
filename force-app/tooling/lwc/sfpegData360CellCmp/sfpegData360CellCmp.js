/***
* @author P-E GROS
* @date   Oct 2026
* @description  LWC Component displaying a clickable cell value within the sfpegData360DatatableCmp datatable.
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

import { LightningElement, api } from 'lwc';

export default class SfpegData360CellCmp extends LightningElement {

    //----------------------------------------------------------------
    // Configuration fields (set by the datatable custom type)
    //----------------------------------------------------------------
    @api value;         // raw value of the cell
    @api label;         // label of the cell column
    @api displayType;   // display type of the value ('text', 'number', 'date-local' or 'date')

    //----------------------------------------------------------------
    // Custom Getters
    //----------------------------------------------------------------
    get isNumber() {
        return this.displayType === 'number';
    }
    get isDate() {
        return this.displayType === 'date-local';
    }
    get isDatetime() {
        return this.displayType === 'date';
    }
    get textValue() {
        if ((this.value === null) || (this.value === undefined)) return '';
        return (typeof this.value === 'object') ? JSON.stringify(this.value) : String(this.value);
    }

    //----------------------------------------------------------------
    // Event Handlers
    //----------------------------------------------------------------
    // Event bubbling and composed to cross the datatable shadow boundary
    handleClick(event) {
        this.dispatchEvent(new CustomEvent('cellinspect', {
            bubbles: true,
            composed: true,
            detail: {label: this.label, value: this.value}
        }));
    }
}
