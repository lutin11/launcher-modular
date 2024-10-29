
import QtQuick 2.12
import Lomiri.Components 1.3
import QtQuick.Controls 2.2 as QControls
import QtQuick.XmlListModel 2.12

PageHeader {
	id:_header
	
	signal sectionChanged(var section, var sectionIdx);
	
	property alias message: msgText
	property alias messageBKColor: message.color
	property alias sectionsModel : _sections.model
	
	extension: Column {
		width: parent.width
		height: (_sections.height*_sections.visible) + (message.height*message.visible)
		Behavior on height { LomiriNumberAnimation { duration:UbuntuAnimation.SlowDuration } }

		Sections {
			id:_sections
			anchors {
				leftMargin: units.gu(2)
				rightMargin: units.gu(2)
				left:parent.left
				right:parent.right
			}
			visible:model != null && model.length;
		
			model:null
			
			onSelectedIndexChanged: if(visible){
				_header.sectionChanged(model[selectedIndex],selectedIndex)
			}
		}
		
		Rectangle {
			id:message
			clip:true
			opacity:0
			visible: opacity !== 0;
			Behavior on opacity { LomiriNumberAnimation { duration:UbuntuAnimation.SlowDuration } }

			
			height: visible ?  msgText.height + units.gu(1) : 0
			width:parent.width
			
			Timer {
				id:messageTimer
				repeat: false
				interval:6000
				onTriggered: { 
					message.opacity=0; 
					msgText.text=null;
				}
			}

			color: theme.palette.normal.raised
			Label {
				id:msgText
				anchors.centerIn: parent
				width:parent.width
				text: null
				color: theme.palette.normal.raisedText
				wrapMode:Text.Wrap
				horizontalAlignment:Text.AlignHCenter
				onTextChanged: if( text ){ 
					messageTimer.restart(); 
					message.opacity=1; 
				}
			}
		}
	}
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

