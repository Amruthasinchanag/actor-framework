<?xml version='1.0' encoding='UTF-8'?>
<Project Type="Project" LVVersion="20008000">
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
		<Item Name="GProviders" Type="Folder">
			<Item Name="ActorMessageMaker.ini" Type="Document" URL="../GProviders/ActorMessageMaker.ini"/>
			<Item Name="AddActor.ini" Type="Document" URL="../GProviders/AddActor.ini"/>
			<Item Name="AddActorInterface.ini" Type="Document" URL="../GProviders/AddActorInterface.ini"/>
			<Item Name="MessageMaker.ini" Type="Document" URL="../GProviders/MessageMaker.ini"/>
			<Item Name="MessageRescripter.ini" Type="Document" URL="../GProviders/MessageRescripter.ini"/>
		</Item>
		<Item Name="Install Support" Type="Folder">
			<Item Name="AFPP Post-Uninstall Custom Action.vi" Type="VI" URL="../Install Support/AFPP Post-Uninstall Custom Action.vi"/>
			<Item Name="AFPP Pre-Install Custom Action.vi" Type="VI" URL="../Install Support/AFPP Pre-Install Custom Action.vi"/>
		</Item>
		<Item Name="Message Templates" Type="Folder">
			<Item Name="Abstract Message Template" Type="Folder">
				<Item Name="Abstract Message Template.lvclass" Type="LVClass" URL="../MessageMakerProvider/_Message Maker/_templates/Abstract Message Template/Abstract Message Template.lvclass"/>
			</Item>
			<Item Name="Concrete Message Template" Type="Folder">
				<Item Name="Concrete Message Template.lvclass" Type="LVClass" URL="../MessageMakerProvider/_Message Maker/_templates/Concrete Message Template/Concrete Message Template.lvclass"/>
				<Item Name="Dummy Read Attributes.vi" Type="VI" URL="../MessageMakerProvider/_Message Maker/_templates/Concrete Message Template/Dummy Read Attributes.vi"/>
			</Item>
			<Item Name="Message Template" Type="Folder">
				<Item Name="Dummy Actor Method.vi" Type="VI" URL="../MessageMakerProvider/_Message Maker/_templates/Message Template/Dummy Actor Method.vi"/>
				<Item Name="Message Template.lvclass" Type="LVClass" URL="../MessageMakerProvider/_Message Maker/_templates/Message Template/Message Template.lvclass"/>
			</Item>
		</Item>
		<Item Name="Actor Message Maker Provider.lvlib" Type="Library" URL="../ActorMessageMaker/Actor Message Maker Provider.lvlib"/>
		<Item Name="Add Actor Interface.lvlib" Type="Library" URL="../AddActorInterface/Add Actor Interface.lvlib"/>
		<Item Name="Add Actor.lvlib" Type="Library" URL="../AddActor/Add Actor.lvlib"/>
		<Item Name="AFPP Shared.lvlib" Type="Library" URL="../MessageMakerProvider/AFPP Shared/AFPP Shared.lvlib"/>
		<Item Name="Message Maker Provider.lvlib" Type="Library" URL="../MessageMakerProvider/Message Maker Provider.lvlib"/>
		<Item Name="Message Maker.lvlib" Type="Library" URL="../MessageMakerProvider/_Message Maker/Message Maker.lvlib"/>
		<Item Name="Message Rescripter.lvlib" Type="Library" URL="../MessageRescripter/Message Rescripter.lvlib"/>
		<Item Name="Dependencies" Type="Dependencies"/>
		<Item Name="Build Specifications" Type="Build"/>
	</Item>
</Project>
