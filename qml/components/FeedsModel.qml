import QtQuick 2.12
import QtQuick.XmlListModel 2.12
import QtQml.Models 2.2

ListModel {
	id:feedModel
	dynamicRoles:true
	property var sortOrder: appSettings.mainFeedSortAsc;
	property var sorting: false;
	
	property var specialSort: {
		'updated' : function(itm) {return Date.parse(itm);}
	};

	onSortOrderChanged: sort();
	
	function sort() {
		console.log("Sorting...")
		var mins = false; var maxs = false;
		for(var i=0; i < feedModel.count;i++) {
			var val = feedModel.getValue(feedModel.get(i));
			if ( mins == false || val !== false && val < mins ) {
				mins = val;
			}
			if ( maxs == false ||  maxs < val ) {
				maxs = val;
			}
		}
		var sorted = [];
		sorted.length = feedModel.count;
		if(maxs - mins == 0 ) {
			return ;
		}
		var factor =  feedModel.count / (maxs - mins);
		for(var i=0; i < feedModel.count;i++) {
			var value = JSON.parse(JSON.stringify(feedModel.get(i)));;
			var val = feedModel.getValue(value);
			var eIdx = val !== false ? parseInt((val - mins) * factor) : 0;
			if(isNaN(eIdx)) {
				eIdx = 0;
			}
			if(sorted[eIdx]) {
				while( sorted[eIdx] ) {
					//console.log(eIdx,i,val);
					if( val < feedModel.getValue(sorted[eIdx]) ) {
						var tmp = sorted[eIdx];
						sorted[eIdx] = value;
						val = feedModel.getValue(tmp);
						value = tmp;
					}
					eIdx++;
				}
				sorted[eIdx] = value;
			} else {
				sorted[eIdx] = value;
			}
		}
		
		var inIdx = sortOrder == Qt.AscendingOrder ? 0 : feedModel.count;
		feedModel.clear();
		for(var idx=sortOrder == Qt.AscendingOrder ? 0 : sorted.length;  
			sortOrder == Qt.AscendingOrder  && idx < sorted.length || sortOrder !== Qt.AscendingOrder  && idx > 0  ; 
			idx+= sortOrder == Qt.AscendingOrder ? 1 : -1) {
			if(sorted[idx]) {
				feedModel.append(sorted[idx]);
				inIdx += sortOrder == Qt.AscendingOrder ? 1 : -1;
			}
		}
		console.log("Done Sorting.")
	}
	// true if a is less then b
	function lessThen(a,b) {
		return 	a === undefined || a[appSettings.mainFeedSortField] === undefined || //does 'a' even exists?
				(b[appSettings.mainFeedSortField] !== undefined  && ( //well if it does it can't be less then undefined...
				( specialSort[appSettings.mainFeedSortField] && specialSort[appSettings.mainFeedSortField](a[appSettings.mainFeedSortField]) < specialSort[appSettings.mainFeedSortField](b[appSettings.mainFeedSortField]) ) //do we have a special handleing for the selected field? 
				||
				(specialSort[appSettings.mainFeedSortField] === undefined && a[appSettings.mainFeedSortField] < b[appSettings.mainFeedSortField] ) ) );// or do we just sort it by the string value?
	}
	
	function getValue(i) {
		if(i === undefined || i[appSettings.mainFeedSortField] === undefined ) {
			return false;
		}
		if ( specialSort[appSettings.mainFeedSortField] ) {//do we have a special handleing for the selected field? 
			return specialSort[appSettings.mainFeedSortField](i[appSettings.mainFeedSortField]) ;
		}
		
		return i[appSettings.mainFeedSortField];
	}
	
	Component.onCompleted:sort();
}
/*
 * Copyright (C) 2021  Eran DarkEye Uzan
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * darkeye.ursses is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */



