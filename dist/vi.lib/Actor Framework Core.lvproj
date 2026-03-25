<?xml version='1.0' encoding='UTF-8'?>
<Project Type="Project" LVVersion="20008000">
	<Property Name="CCSymbols" Type="Str">AF_Debug_Trace,False;</Property>
	<Property Name="NI.LV.All.SaveVersion" Type="Str">20.0</Property>
	<Property Name="NI.LV.All.SourceOnly" Type="Bool">true</Property>
	<Property Name="NI.Project.Description" Type="Str"></Property>
	<Item Name="My Computer" Type="My Computer">
		<Property Name="server.app.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.control.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.tcp.enabled" Type="Bool">false</Property>
		<Property Name="server.tcp.port" Type="Int">0</Property>
		<Property Name="server.tcp.serviceName" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.tcp.serviceName.default" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.vi.callsEnabled" Type="Bool">true</Property>
		<Property Name="server.vi.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="specify.custom.address" Type="Bool">false</Property>
		<Item Name="Deprecated Messages" Type="Folder">
			<Item Name="Batch Msg.lvclass" Type="LVClass" URL="../ActorFramework/Batch Msg/Batch Msg.lvclass"/>
			<Item Name="Reply Msg.lvclass" Type="LVClass" URL="../ActorFramework/Reply Msg/Reply Msg.lvclass"/>
			<Item Name="Report Error Msg.lvclass" Type="LVClass" URL="../ActorFramework/Report Error Msg/Report Error Msg.lvclass"/>
			<Item Name="Self-Addressed Msg.lvclass" Type="LVClass" URL="../ActorFramework/Self-Addressed Msg/Self-Addressed Msg.lvclass"/>
		</Item>
		<Item Name="Install Support" Type="Folder">
			<Item Name="Post-Uninstall Custom Action.vi" Type="VI" URL="../Install Support/Post-Uninstall Custom Action.vi"/>
			<Item Name="Pre-Install Custom Action.vi" Type="VI" URL="../Install Support/Pre-Install Custom Action.vi"/>
		</Item>
		<Item Name="Palette Items" Type="Folder">
			<Item Name="Enqueuer Constant.vi" Type="VI" URL="../ActorFramework/Palette Items/Enqueuer Constant.vi"/>
			<Item Name="Enqueuer Control.vi" Type="VI" URL="../ActorFramework/Palette Items/Enqueuer Control.vi"/>
			<Item Name="Last Ack Constant.vi" Type="VI" URL="../ActorFramework/Palette Items/Last Ack Constant.vi"/>
			<Item Name="Last Ack Control.vi" Type="VI" URL="../ActorFramework/Palette Items/Last Ack Control.vi"/>
		</Item>
		<Item Name="Test Harness" Type="Folder">
			<Item Name="Actor with Nesteds.lvlib" Type="Library" URL="../Testing/Test Harness/Actor with Nesteds/Actor with Nesteds.lvlib"/>
			<Item Name="AF Trace Queue.lvclass" Type="LVClass" URL="../Testing/Test Harness/AF Trace Queue/AF Trace Queue.lvclass"/>
		</Item>
		<Item Name="Testing Support" Type="Folder">
			<Item Name="Test Launch For Nested Actor Without Caller.vi" Type="VI" URL="../ActorFramework/Testing Support/Test Launch For Nested Actor Without Caller.vi"/>
		</Item>
		<Item Name="Tests" Type="Folder">
			<Item Name="Launch Root Actor_Actor_Generates Actor Traces.vi" Type="VI" URL="../Testing/Tests/Launch Root Actor_Actor_Generates Actor Traces.vi"/>
			<Item Name="Stop Autostop Nested Actors_Stops Nested Actors.vi" Type="VI" URL="../Testing/Tests/Stop Autostop Nested Actors_Stops Nested Actors.vi"/>
		</Item>
		<Item Name="Actor Framework.lvlib" Type="Library" URL="../ActorFramework/Actor Framework.lvlib"/>
		<Item Name="AF Debug.lvlib" Type="Library" URL="../../resource/AFDebug/AF Debug.lvlib"/>
		<Item Name="AF Specialty Messages.lvlib" Type="Library" URL="../ActorFramework/AF Specialty Messages.lvlib"/>
		<Item Name="Casting Utility For Actors.vim" Type="VI" URL="../ActorFramework/Actor/Casting Utility For Actors.vim"/>
		<Item Name="Dependencies" Type="Dependencies"/>
		<Item Name="Build Specifications" Type="Build"/>
	</Item>
</Project>
