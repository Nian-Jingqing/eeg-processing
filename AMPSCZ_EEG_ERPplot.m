function AMPSCZ_EEG_ERPplot( EEG, epochInfo )
% ERP plots from the output of AMPSCZ_EEG_preproc.m
% 
% Usage:
% >> AMPSCZ_EEG_ERPplot( EEG, epochInfo )

% S:\bieegl01\Delta\napls3\matlab or github
% see grandAverage_NAPLS_LTP_ERPs.m loads mat-files for plotting
%     massUnivariateClusterTest_NAPLS_LTP_ERPs.m
%     plotLTPerps.m

			% BJR code
			% VODMMN
			% 	MMN plot Fz for standard & all deviant types
			% 	VOD plot Oz for standard
			% 	         Pz for target
			% 				find pos peak for Pz target [200,600]ms
			% 					topo mean standard w/i 25ms of peak
			% 					topo mean target   w/i 25ms of peak
			% #				find pos peak for Cz novel [200,600]ms
			% #					topo mean novel w/i 25ms of peak
			% AOD
			% 	no plots
			
			% New Spec
			% AOD or VOD
			%	plot Pz & Cz (possibly Fz too?)
			%   get target peak from Pz difference
			%       novel  peak from Cz difference
			% MMN
			%   plot Fz (& Cz?)
			
			% MMN in negative component 100-250 ms after stimulus
			
			% tpk = Peakmm3(nanmean(EEG.data(Pz,:,events==100),3)', EEG.times, 200,600,'pos');


		% From Gregory Light to Everyone:  04:21 PM
		% https://www.frontiersin.org/articles/10.3389/fninf.2015.00016/full			PREP?  bad channels iterative common average
		% https://sccn.ucsd.edu/wiki/Makoto's_preprocessing_pipeline					too ICA based but interesting


	narginchk( 1, 2 )
	% suppress warning about (xmax-xmin)*srate+1 ~= pnts?
% 	if isstruct( EEG ) && all( isfield( EEG, fieldnames( eeg_checkset( eeg_emptyset ) ) ) )
	blank = eeg_emptyset;
	blank.xmin = 1;				% eeg_checkset sets xmax to -1 instead
	blank = eeg_checkset( blank );
	if isstruct( EEG ) && all( isfield( EEG, fieldnames( blank ) ) )
% 		if ~isstruct( epochInfo ) || ~all( isfield( epochInfo, { 'latency', 'kTarget', 'kNovel', 'kCorrect', 'Nstandard', 'respLat' } ) )
		if ~isstruct( epochInfo ) || ~all( isfield( epochInfo, { 'latency', 'kStandard', 'kTarget', 'kNovel', 'kCorrect', 'respLat' } ) )
			error( 'invalid epochInfo structure' )
		end
	elseif ischar( EEG ) && exist( EEG, 'file' ) == 2 && strncmp( flip( EEG, 2 ), 'tam.', 4 )
		EEG = load( EEG );
		if ~isfield( EEG, 'EEG' )
			error( 'invalid mat-file' )
		end
		epochInfo = EEG.epochInfo;
		EEG       = EEG.EEG;
	else
		error( 'invalid EEG input' )
	end
	
	% concatenate epoch info across runs
	for fn = fieldnames( epochInfo )'
		epochInfo(1).(fn{1}) = [ epochInfo.(fn{1}) ];
	end
	epochInfo = epochInfo(1);
	
	tWinPlot   = [ -100, 500 ];	% (ms)
% 	tWidthTopo = 0;
	tWidthTopo = 25*2;
	
	Ichan  = find( strcmp( { EEG.chanlocs.type }, 'EEG' ) );
	nChan  = numel( Ichan );
% 	nSamp  = EEG.pnts;
% 	nEpoch = EEG.trials;

	jTime = EEG.times >= tWinPlot(1) & EEG.times <= tWinPlot(2);
	jT0   = find( jTime, 1, 'first' ) - 1;
	nTime = sum( jTime );

	% pull out the latency=0 events from each epoch, cell array of 'S#' codes, should all be stim codes, not responses
	eventType = cellfun( @(u,v)u{[v{:}]==0}, { EEG.epoch.eventtype }, { EEG.epoch.eventlatency }, 'UniformOutput', false );
	if numel( eventType ) ~= EEG.trials
		error( 'huh?' )
	end
	
% 	chanSet = {
% 		'Cz-centered', { 'Cz', 'FC1',        'FC2', 'C1', 'C2', 'CP1', 'CPz', 'CP2' }
% 		'Pz-centered', { 'Pz', 'CP1', 'CPz', 'CP2', 'P1', 'P2', 'PO3', 'POz', 'PO4' }
% 	};
% 	chanSet = {
% 		'Cz', { 'Cz' }
% 		'Pz', { 'Pz' }
% 	};

	% Get epochName
	% EEG.comments will have VODMMN combined
	% there's got to be a better way to identify task! probably should just make it an input since it's saved in mat-files
	switch eventType{1}
		case { 'S  1', 'S  2', 'S  4', 1, 2, 4 }
			epochName   = 'AOD';
			% { label, channel members }
			chanSet = {
				'Cz', { 'Cz' }
				'Pz', { 'Pz' }
			};
			figSize  = [ 1000, 700 ];
		case { 'S 16', 'S 18', 16, 18 }
			epochName   = 'MMN';
			chanSet = {
				'Fz', { 'Fz' }
				'Cz', { 'Cz' }
			};
			figSize  = [ 500, 700 ];
		case { 'S 32', 'S 64', 'S128', 32, 64, 128 }
			epochName   = 'VOD';
% 			chanSet = {
% 				'Pz', { 'Pz' }		% target & peak detection
% 				'Oz', { 'Oz' }		% standard
% 			};
			chanSet = {
				'Cz', { 'Cz' }		%  novel - standard
				'Pz', { 'Pz' }		% target - standard
			};
			figSize  = [ 1000, 700 ];
		case { 'S  8', 8 }
			epochName   = 'ASSR';
% 		case { 'S 20 ', 20 }
% 			epochName = 'RestEO';
% 		case { 'S 24', 24 }
% 			epochName = 'RestEC';
		otherwise
			error( 'can''t identify task' )
	end

	% convert cell arrays of channel names to numeric indices
	nSet = size( chanSet, 1 );		% # waveform axes
	for iSet = 1:nSet
%		     chanSet{iSet,2}   = eeg_chaninds( EEG, chanSet{iSet,2} );			% beware: eeg_chaninds.m sorts indices
		[ ~, chanSet{iSet,2} ] = ismember( chanSet{iSet,2}, { EEG.chanlocs(Ichan).labels } );
		if any( chanSet{iSet,2} == 0 )
			error( 'unknown channel(s)' )
		end
	end

		% double-check EEG structure against epochInfo?
%		[ standardCode, targetCode, novelCode ] = AMPSCZ_EEG_eventCodes( epochName );
%		if ~isempty( [ standardCode, targetCode, novelCode ] )
%			if numel( eventType ) ~= numel( epochInfo.kTarget )
%				error( 'epoch event type bug' )
%			elseif ~isempty( targetCode ) && ~all( strcmp( eventType( epochInfo.kTarget ), targetCode ) )
%				error( 'epoch event type bug' )
%			elseif ~isempty(  novelCode ) && ~all( strcmp( eventType( epochInfo.kNovel  ),  novelCode ) )
%				error( 'epoch event type bug' )
%			end
%		end

	[ standardCode, targetCode, novelCode ] = AMPSCZ_EEG_eventCodes( epochName );
	% non-rejected epochs
	kEpoch = shiftdim( ~isnan( EEG.data(1,1,:) ), 1 );
	nanFlag = 'includenan';		% shouldn't be any NaNs, include them as safety
	
	topoOpts = { 'style', 'map', 'electrodes', 'pts', 'nosedir', '+Y', 'conv', 'on', 'shading', 'interp' };		% electrodes: 'pts' or 'ptslabels'?

	fontSize = 10;
	subjSess = regexp( EEG.comments, '^Original file: sub-([A-Z]{2}\d{5})_ses-(\d{8})_task-\S+_run-\d+_eeg.eeg$', 'tokens', 'once' );
			
	% stop automatic datatips - they're super annoying!
	set( groot , 'defaultAxesCreateFcn' , 'disableDefaultInteractivity(gca)' )
	
	switch epochName

		case 'MMN'

			Kstandard = epochInfo.kStandard;
			Kdeviant  = epochInfo.kNovel;
			% only analyze correct responses?		don't worry about button presses in MMN task.  DM 12/13/21
% 			Kstandard(Kstandard) = epochInfo.kCorrect(Kstandard);
% 			Kdeviant(Kdeviant)   = epochInfo.kCorrect(Kdeviant);
			% non-rejected epochs
			Kstandard(Kstandard) = kEpoch(Kstandard);
			Kdeviant(Kdeviant)   = kEpoch(Kdeviant);
			% average across epochs
			YmStandard = mean( EEG.data(Ichan,jTime,Kstandard), 3, nanFlag );
			YmDeviant  = mean( EEG.data(Ichan,jTime,Kdeviant ), 3, nanFlag );
			% average aross channels, #sets x #samples matrices
			[ ymStandard, ymDeviant ] = deal( zeros( nSet, nTime ) );
			for iSet = 1:nSet
				ymStandard(iSet,:) = mean( YmStandard(chanSet{iSet,2},:), 1, nanFlag );
				ymDeviant(iSet,:)  = mean(  YmDeviant(chanSet{iSet,2},:), 1, nanFlag );
			end
			% plot limits
% 			yRange = yRangeFcn( cat( 3, YmStandard, YmDeviant, YmDeviant - YmStandard ) );
			yRange = yRangeFcn( cat( 3, ymStandard, ymDeviant, ymDeviant - ymStandard ) );
			kSet = strcmp( chanSet(:,1), 'Fz' );
			if sum( kSet ) ~= 1
				error( 'invalid channel set name' )
			end
			kPk = EEG.times(jTime) >= 80 & EEG.times(jTime) <= 250;
			[ ~, jPk ] = findpeaks( ymStandard(kSet,kPk) - ymDeviant(kSet,kPk) );
			switch numel( jPk )
				case 1
				case 0		% use an endpoint if no peaks?
					[ ~, jPk ] = min( ymDeviant(kSet,kPk) - ymStandard(kSet,kPk) );
				otherwise
% 					EEG.times(jPk+jT0)
					ikPk = find( kPk );
					[ ~, ijPk ] = min( ymDeviant(kSet,ikPk(jPk)) - ymStandard(kSet,ikPk(jPk)) );
					jPk = jPk(ijPk);
% 					EEG.times(jPk+jT0)
					clear ikPk
			end
			jPk(:) = jPk + find( kPk, 1, 'first' ) - 1;
			jt = jPk + jT0;
			
			[ tmStandard, tmDeviant ] = deal( nan( nChan, 2 ) );
			if tWidthTopo == 0
				tmStandard(:,1) = YmStandard(:,jPk);
				tmDeviant(:,1)  =  YmDeviant(:,jPk);
				tStr1 = sprintf( '%0.0f ms', EEG.times(jt) );
			else
				tAvg = EEG.times(jt) + [ -1, 1 ]*tWidthTopo/2;
				jAvg = EEG.times(jTime) >= tAvg(1) & EEG.times(jTime) <= tAvg(2);
				tmStandard(:,1) = mean( YmStandard(:,jAvg), 2, nanFlag );
				tmDeviant(:,1)  = mean(  YmDeviant(:,jAvg), 2, nanFlag );
				tStr1 = sprintf( '%0.0f \\pm %0.0f ms', EEG.times(jt), tWidthTopo/2 );
			end
			tFix = 120;
			wFix = tWidthTopo;
			tAvg = tFix + [ -1, 1 ]*wFix/2;
			jAvg = EEG.times(jTime) >= tAvg(1) & EEG.times(jTime) <= tAvg(2);
			tmStandard(:,2) = mean( YmStandard(:,jAvg), 2, nanFlag );
			tmDeviant(:,2)  = mean(  YmDeviant(:,jAvg), 2, nanFlag );
% 			tStr2 = sprintf( '[ %0.0f, %0.0f ] ms', tAvg );
			tStr2 = sprintf( '%0.0f \\pm %0.0f ms', tFix, wFix/2 );

			hFig  = figure( 'Position', [ 600, 150, figSize ], 'Colormap', jet(256) );		% 225% SCN laptop
			hAx   = gobjects( 2*nSet+4, 1 );
			hTopo = gobjects(        4, 1 );

			topoOpts = [ topoOpts, { 'maplimits', yRange } ];
			pkColor = [ 1, 0, 0 ];
			
			axL  = 0.1;
			axR  = 0.05;
			axT  = 0.1;
			axB  = 0.05;
			axGh = 0.075;
			axGv = [ 0.05, 0.1, 0.05 ];
			axH = ( 1 - axT - axB - (nSet-1)*axGv(1) - axGv(2) - axGv(3) ) / ( nSet + 2 );
			axW = ( 1 - axL - axR - axGh ) / 2;		% left, right, middle

			% Plot
			for iSet = 1:nSet
				% waveforms
				py = 1 - axT + axGv(1) - ( axGv(1) + axH )*iSet;
				hAx(2*iSet-1) = subplot( 'Position', [ axL         , py, axW, axH ] );	%subplot( nSet+2, 2, 2*iSet-1 );
				hAx(2*iSet)   = subplot( 'Position', [ axL+axW+axGh, py, axW, axH ] );	%subplot( nSet+2, 2, 2*iSet );
				plot( hAx(2*iSet-1), EEG.times(jTime), ymStandard(iSet,:), 'k', EEG.times(jTime), ymDeviant(iSet,:), 'r' )
				plot( hAx(2*iSet)  , EEG.times(jTime), ymDeviant(iSet,:) - ymStandard(iSet,:), 'r' )
			end
			% topographies
			% -- peak detection
			py(:) = 1 - axT + axGv(1) - ( axGv(1) + axH )*nSet - axGv(2) - axH;
			hAx(2*nSet+1) = subplot( 'Position', [ axL, py, axW, axH ] );	%subplot( nSet+2, 2, 2*iSet+1 );
				hTopo(1) = topoplot( tmDeviant(:,1), EEG.chanlocs(Ichan), topoOpts{:} );
			hAx(2*nSet+2) = subplot( 'Position', [ axL+axW+axGh, py, axW, axH ] );	%subplot( nSet+2, 2, 2*iSet+2 );
				hTopo(2) = topoplot( tmDeviant(:,1) - tmStandard(:,1), EEG.chanlocs(Ichan), topoOpts{:} );
			% -- fixed time range
			py(:) = py - axGv(3) - axH;
			hAx(2*nSet+3) = subplot( 'Position', [ axL, py, axW, axH ] );	%subplot( nSet+2, 2, 2*iSet+3 );
				hTopo(3) = topoplot( tmDeviant(:,2), EEG.chanlocs(Ichan), topoOpts{:} );
			hAx(2*nSet+4) = subplot( 'Position', [ axL+axW+axGh, py, axW, axH ] );	%subplot( nSet+2, 2, 2*iSet+4 );
				hTopo(4) = topoplot( tmDeviant(:,2) - tmStandard(:,2), EEG.chanlocs(Ichan), topoOpts{:} );

			set( hAx(1:nSet*2), 'XLim', tWinPlot, 'YLim', yRange, 'CLim', yRange, 'FontSize', 8, 'XGrid', 'on', 'YGrid', 'on' )
			set( hAx(1:(nSet-1)*2), 'XTickLabel', '' )
% 			set( hAx(iSet), 'UserData', iSet )
			set( hAx(nSet*2+1:end), 'XLim', [ -0.5, 0.5 ], 'YLim', [ -0.4, 0.45 ] )

			title( hAx(1), sprintf( '{\\fontsize{%d}%s\n{\\rm%s  (%s-%s-%s)}}\nStandard (%d)  \\color{red}Deviant (%d)', fontSize+2,...
				epochName, subjSess{1}, subjSess{2}(1:4), subjSess{2}(5:6), subjSess{2}(7:8), sum( Kstandard ), sum( Kdeviant ) ), 'FontSize', fontSize )
			title( hAx(2), '\color{red}Deviant - Standard', 'FontSize', fontSize )
			for iSet = 1:nSet
				ylabel( hAx(2*iSet-1), [ chanSet{iSet,1}, ' (\muV)' ], 'FontSize', fontSize, 'FontWeight', 'bold' )
			end
			xlabel( hAx(2*nSet-1), 'Time (ms)', 'FontSize', fontSize, 'FontWeight', 'bold' )
			xlabel( hAx(2*nSet)  , 'Time (ms)', 'FontSize', fontSize, 'FontWeight', 'bold' )
			title(  hAx(2*nSet+1), 'Deviant', 'FontSize', fontSize )
			title(  hAx(2*nSet+2), 'Deviant - Standard', 'FontSize', fontSize )
			ylabel( hAx(2*nSet+1), tStr1, 'Visible', 'on', 'Color', pkColor, 'FontSize', fontSize, 'FontWeight', 'bold' )
			ylabel( hAx(2*nSet+3), tStr2, 'Visible', 'on', 'Color',     'k', 'FontSize', fontSize, 'FontWeight', 'bold' )

			iSet(:) = find( kSet );
			if tWidthTopo == 0
				line( hAx(2*iSet), EEG.times([jt,jt]), yRange, 'Color', pkColor, 'LineStyle', '--' )
			else
				uistack( patch( hAx(2*iSet), EEG.times(jt)+[-1,1,1,-1]*tWidthTopo/2, yRange([1 1 2 2]), repmat( 0.75, 1, 3 ), 'EdgeColor', 'none', 'FaceAlpha', 0.5 ), 'bottom' )
% 				line( hAx(2*iSet), EEG.times([jt,jt]), yRange, 'Color', pkColor, 'LineStyle', '--' )
			end
		
		case { 'VOD', 'AOD' }

			Kstandard = epochInfo.kStandard;
			Ktarget   = epochInfo.kTarget;
			Knovel     = epochInfo.kNovel;
			% only analyze correct responses?		don't worry about button presses in MMN task.  DM 12/13/21
			Kstandard(Kstandard) = epochInfo.kCorrect(Kstandard);
			Ktarget(Ktarget)     = epochInfo.kCorrect(Ktarget);
			Knovel(Knovel)       = epochInfo.kCorrect(Knovel);
			% non-rejected epochs
			Kstandard(Kstandard) = kEpoch(Kstandard);
			Ktarget(Ktarget)     = kEpoch(Ktarget);
			Knovel(Knovel)       = kEpoch(Knovel);
			% average across epochs
			YmStandard = mean( EEG.data(Ichan,jTime,Kstandard), 3, nanFlag );
			YmTarget   = mean( EEG.data(Ichan,jTime,Ktarget  ), 3, nanFlag );
			YmNovel    = mean( EEG.data(Ichan,jTime,Knovel   ), 3, nanFlag );
			% average aross channels, #sets x #samples matrices
			[ ymStandard, ymTarget, ymNovel ] = deal( zeros( nSet, nTime ) );
			for iSet = 1:nSet
				ymStandard(iSet,:) = mean( YmStandard(chanSet{iSet,2},:), 1, nanFlag );
				ymTarget(iSet,:)   = mean(   YmTarget(chanSet{iSet,2},:), 1, nanFlag );
				ymNovel(iSet,:)    = mean(    YmNovel(chanSet{iSet,2},:), 1, nanFlag );
			end
			% plot limits
% 			yRange = yRangeFcn( cat( 3, YmStandard, YmTarget, YmNovel, YmTarget - YmStandard, YmNovel - YmStandard ) );
			yRange = yRangeFcn( cat( 3, ymStandard, ymTarget, ymNovel, ymTarget - ymStandard, ymNovel - ymStandard ) );
			kSetT = strcmp( chanSet(:,1), 'Pz' );
			if sum( kSetT ) ~= 1
				error( 'invalid channel set name' )
			end
			kSetN = strcmp( chanSet(:,1), 'Cz' );
			if sum( kSetN ) ~= 1
				error( 'invalid channel set name' )
			end
			kPk = EEG.times(jTime) >= 200 & EEG.times(jTime) <= 500;
			[ ~, jPkT ] = findpeaks( ymTarget(kSetT,kPk) - ymStandard(kSetT,kPk) );
			[ ~, jPkN ] = findpeaks(  ymNovel(kSetN,kPk) - ymStandard(kSetN,kPk) );
			switch numel( jPkT )
				case 1
				case 0		% use an endpoint if no peaks?
					[ ~, jPkT ] = max( ymTarget(kSetT,kPk) - ymStandard(kSetT,kPk) );
				otherwise
					ikPk = find( kPk );
					[ ~, ijPk ] = max( ymTarget(kSetT,ikPk(jPkT)) - ymStandard(kSetT,ikPk(jPkT)) );
					jPkT = jPkT(ijPk);
					clear ikPk
			end
			switch numel( jPkN )
				case 1
				case 0		% use an endpoint if no peaks?
					[ ~, jPkN ] = max( ymNovel(kSetN,kPk) - ymStandard(kSetN,kPk) );
				otherwise
					ikPk = find( kPk );
					[ ~, ijPk ] = max( ymNovel(kSetN,ikPk(jPkN)) - ymStandard(kSetN,ikPk(jPkN)) );
					jPkN = jPkN(ijPk);
					clear ikPk
			end
			jPkT(:) = jPkT + find( kPk, 1, 'first' ) - 1;
			jPkN(:) = jPkN + find( kPk, 1, 'first' ) - 1;
			jtT = jPkT + jT0;
			jtN = jPkN + jT0;
			
			[ tmStandardT, tmStandardN, tmTarget, tmNovel ] = deal( nan( nChan, 2 ) );
			if tWidthTopo == 0
				tmStandardT(:,1) = YmStandard(:,jPkT);
				tmStandardN(:,1) = YmStandard(:,jPkN);
				tmTarget(:,1)    =   YmTarget(:,jPkT);
				tmNovel(:,1)     =    YmNovel(:,jPkN);
				tStr1T = sprintf( '%0.0f ms', EEG.times(jtT) );
				tStr1N = sprintf( '%0.0f ms', EEG.times(jtN) );
			else
				tAvg = EEG.times(jtT) + [ -1, 1 ]*tWidthTopo/2;
				jAvg = EEG.times(jTime) >= tAvg(1) & EEG.times(jTime) <= tAvg(2);
				tmStandardT(:,1) = mean( YmStandard(:,jAvg), 2, nanFlag );
				tmTarget(:,1)    = mean(   YmTarget(:,jAvg), 2, nanFlag );
				tAvg = EEG.times(jtN) + [ -1, 1 ]*tWidthTopo/2;
				jAvg = EEG.times(jTime) >= tAvg(1) & EEG.times(jTime) <= tAvg(2);
				tmStandardN(:,1) = mean( YmStandard(:,jAvg), 2, nanFlag );
				tmNovel(:,1)     = mean(    YmNovel(:,jAvg), 2, nanFlag );
				tStr1T = sprintf( '%0.0f \\pm %0.0f ms', EEG.times(jtT), tWidthTopo/2 );
				tStr1N = sprintf( '%0.0f \\pm %0.0f ms', EEG.times(jtN), tWidthTopo/2 );
			end
			tFix = 350;		% AOD ~ 330 target, 320 novel; VOD ~ 410 target, 355 novel
			wFix = tWidthTopo;
			tAvg = tFix + [ -1, 1 ]*wFix/2;
			jAvg = EEG.times(jTime) >= tAvg(1) & EEG.times(jTime) <= tAvg(2);
			tmStandardT(:,2) = mean( YmStandard(:,jAvg), 2, nanFlag );
			tmTarget(:,2)    = mean(   YmTarget(:,jAvg), 2, nanFlag );
			tmStandardN(:,2) = mean( YmStandard(:,jAvg), 2, nanFlag );
			tmNovel(:,2)     = mean(    YmNovel(:,jAvg), 2, nanFlag );
			tStr2 = sprintf( '%0.0f \\pm %0.0f ms', tFix, wFix/2 );


			hFig  = figure( 'Position', [ 600, 150, figSize ], 'Colormap', jet(256) );		% 225% SCN laptop
			hAx   = gobjects( 4*nSet+8, 1 );
			hTopo = gobjects(        8, 1 );
			
			topoOpts = [ topoOpts, { 'maplimits', yRange } ];
			pkColorT = [ 0, 0, 1 ];
			pkColorN = [ 1, 0, 0 ];
			
			axL  = 0.1;
			axR  = 0.05;
			axT  = 0.1;
			axB  = 0.05;
			axGh = 0.075;
			axGv = [ 0.05, 0.1, 0.05 ];
			axH = ( 1 - axT - axB - (nSet-1)*axGv(1) - axGv(2) - axGv(3) ) / ( nSet + 2 );
			axW = ( 1 - axL - axR - axGh*3 ) / 4;		% left, right, middle

			% Plot
			for iSet = 1:nSet
				% waveforms
				py = 1 - axT + axGv(1) - ( axGv(1) + axH )*iSet;
				hAx(4*iSet-3) = subplot( 'Position', [ axL             , py, axW, axH ] );
				hAx(4*iSet-2) = subplot( 'Position', [ axL+axW+axGh    , py, axW, axH ] );
				hAx(4*iSet-1) = subplot( 'Position', [ axL+(axW+axGh)*2, py, axW, axH ] );
				hAx(4*iSet)   = subplot( 'Position', [ axL+(axW+axGh)*3, py, axW, axH ] );
				plot( hAx(4*iSet-3), EEG.times(jTime), ymStandard(iSet,:), 'k', EEG.times(jTime), ymTarget(iSet,:), 'b' )
				plot( hAx(4*iSet-2), EEG.times(jTime),   ymTarget(iSet,:) - ymStandard(iSet,:), 'b' )
				plot( hAx(4*iSet-1), EEG.times(jTime), ymStandard(iSet,:), 'k', EEG.times(jTime), ymNovel(iSet,:), 'r' )
				plot( hAx(4*iSet)  , EEG.times(jTime),    ymNovel(iSet,:) - ymStandard(iSet,:), 'r' )
			end
			% topographies
			% -- peak detection
			py(:) = 1 - axT + axGv(1) - ( axGv(1) + axH )*nSet - axGv(2) - axH;
			hAx(4*nSet+1) = subplot( 'Position', [ axL, py, axW, axH ] );
				hTopo(1) = topoplot( tmTarget(:,1), EEG.chanlocs(Ichan), topoOpts{:} );
			hAx(4*nSet+2) = subplot( 'Position', [ axL+axW+axGh, py, axW, axH ] );
				hTopo(2) = topoplot( tmTarget(:,1) - tmStandardT(:,1), EEG.chanlocs(Ichan), topoOpts{:} );
			hAx(4*nSet+3) = subplot( 'Position', [ axL+(axW+axGh)*2, py, axW, axH ] );
				hTopo(3) = topoplot( tmNovel(:,1), EEG.chanlocs(Ichan), topoOpts{:} );
			hAx(4*nSet+4) = subplot( 'Position', [ axL+(axW+axGh)*3, py, axW, axH ] );
				hTopo(4) = topoplot( tmNovel(:,1) - tmStandardN(:,1), EEG.chanlocs(Ichan), topoOpts{:} );
			% -- fixed time range
			py(:) = py - axGv(3) - axH;
			hAx(4*nSet+5) = subplot( 'Position', [ axL, py, axW, axH ] );
				hTopo(5) = topoplot( tmTarget(:,2), EEG.chanlocs(Ichan), topoOpts{:} );
			hAx(4*nSet+6) = subplot( 'Position', [ axL+axW+axGh, py, axW, axH ] );
				hTopo(6) = topoplot( tmTarget(:,2) - tmStandardT(:,2), EEG.chanlocs(Ichan), topoOpts{:} );
			hAx(4*nSet+7) = subplot( 'Position', [ axL+(axW+axGh)*2, py, axW, axH ] );
				hTopo(7) = topoplot( tmNovel(:,2), EEG.chanlocs(Ichan), topoOpts{:} );
			hAx(4*nSet+8) = subplot( 'Position', [ axL+(axW+axGh)*3, py, axW, axH ] );
				hTopo(8) = topoplot( tmNovel(:,2) - tmStandardN(:,2), EEG.chanlocs(Ichan), topoOpts{:} );

			set( hAx(1:nSet*4), 'XLim', tWinPlot, 'YLim', yRange, 'CLim', yRange, 'FontSize', 8, 'XGrid', 'on', 'YGrid', 'on' )
			set( hAx(1:(nSet-1)*4), 'XTickLabel', '' )
% 			set( hAx(iSet), 'UserData', iSet )
			set( hAx(nSet*4+1:end), 'XLim', [ -0.5, 0.5 ], 'YLim', [ -0.4, 0.45 ] )

			title( hAx(1), sprintf( '{\\fontsize{%g}%s\n{\\rm%s  (%s-%s-%s)}}\nStandard (%d)  \\color{blue}Target (%d)', fontSize+2,...
				epochName, subjSess{1}, subjSess{2}(1:4), subjSess{2}(5:6), subjSess{2}(7:8), sum( Kstandard ), sum( Ktarget ) ), 'FontSize', fontSize )
			title( hAx(2), '\color{blue}Target - Standard', 'FontSize', fontSize )
			title( hAx(3), sprintf( 'Standard  \\color{red}Novel (%d)', sum( Knovel ) ), 'FontSize', fontSize )
			title( hAx(4), '\color{red}Novel - Standard', 'FontSize', fontSize )
			for iSet = 1:nSet
				ylabel( hAx(4*iSet-3), [ chanSet{iSet,1}, ' (\muV)' ], 'FontSize', fontSize, 'FontWeight', 'bold' )
			end
			xlabel( hAx(4*nSet-3), 'Time (ms)', 'FontSize', fontSize, 'FontWeight', 'bold' )
			xlabel( hAx(4*nSet-2), 'Time (ms)', 'FontSize', fontSize, 'FontWeight', 'bold' )
			xlabel( hAx(4*nSet-1), 'Time (ms)', 'FontSize', fontSize, 'FontWeight', 'bold' )
			xlabel( hAx(4*nSet)  , 'Time (ms)', 'FontSize', fontSize, 'FontWeight', 'bold' )
			title(  hAx(4*nSet+1), 'Target'           , 'FontSize', fontSize )
			title(  hAx(4*nSet+2), 'Target - Standard', 'FontSize', fontSize )
			title(  hAx(4*nSet+3), 'Novel'            , 'FontSize', fontSize )
			title(  hAx(4*nSet+4), 'Novel - Standard' , 'FontSize', fontSize )
			ylabel( hAx(4*nSet+1), tStr1T, 'Visible', 'on', 'Color', pkColorT, 'FontSize', fontSize, 'FontWeight', 'bold' )
			ylabel( hAx(4*nSet+3), tStr1N, 'Visible', 'on', 'Color', pkColorN, 'FontSize', fontSize, 'FontWeight', 'bold' )
			ylabel( hAx(4*nSet+5), tStr2 , 'Visible', 'on', 'Color',      'k', 'FontSize', fontSize, 'FontWeight', 'bold' );

			iSet(:) = find( kSetT );
			if tWidthTopo == 0
				line( hAx(4*iSet-2), EEG.times([jtT,jtT]), yRange, 'Color', pkColorT, 'LineStyle', '--' )
			else
				uistack( patch( hAx(4*iSet-2), EEG.times(jtT)+[-1,1,1,-1]*tWidthTopo/2, yRange([1 1 2 2]), repmat( 0.75, 1, 3 ), 'EdgeColor', 'none', 'FaceAlpha', 0.5 ), 'bottom' )
% 				line( hAx(4*iSet), EEG.times([jtT,jtT]), yRange, 'Color', pkColorT, 'LineStyle', '--' )
			end
			iSet(:) = find( kSetN );
			if tWidthTopo == 0
				line( hAx(4*iSet), EEG.times([jtN,jtN]), yRange, 'Color', pkColorN, 'LineStyle', '--' )
			else
				uistack( patch( hAx(4*iSet), EEG.times(jtN)+[-1,1,1,-1]*tWidthTopo/2, yRange([1 1 2 2]), repmat( 0.75, 1, 3 ), 'EdgeColor', 'none', 'FaceAlpha', 0.5 ), 'bottom' )
% 				line( hAx(4*iSet), EEG.times([jtN,jtN]), yRange, 'Color', pkColorN, 'LineStyle', '--' )
			end
			
			
		otherwise
	end
	subplot( 'Position', [ 1-axR*0.75, 1-axT+axGv(1)-(axGv(1)+axH)*iSet, axR*0.5, axH ] )
	image( (256:-1:1)' )
	set( gca, 'YLim', [ 0.5, 256.5 ], 'XTick', [], 'YTick', [] )
	

	figure( hFig )
	
	if isunix
% 		AMPSCZdir = '/data/predict/kcho/flow_test';					% don't work here, outputs will get deleted.  aws rsync to NDA s2
		AMPSCZdir = '/data/predict/kcho/flow_test/spero';			% kevin got rid of group folder & only gave me pronet?	
	else %if ispc
		AMPSCZdir = 'C:\Users\donqu\Documents\NCIRE\AMPSCZ';
	end
	
	siteId   = subjSess{1}(1:2);
	siteInfo = AMPSCZ_EEG_siteInfo;
	kSite    = strcmp( siteInfo(:,1), siteId );
	if sum( kSite ) ~= 1
		error( 'side id bug' )
	end
	networkName = siteInfo{kSite,2};
	
	pngDir = fullfile( AMPSCZdir, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteId ], 'processed', subjSess{1}, 'eeg', [ 'ses-', subjSess{2} ], 'Figures' );
	if ~isfolder( pngDir )
		mkdir( pngDir )
		fprintf( 'created %s\n', pngDir )
	end
	pngOut = fullfile( pngDir, [ subjSess{1}, '_', subjSess{2}, '_', epochName, '.png' ] );		% [ subjTag(5:end), '_', sessTag(5:end), '_QC.png' ]

	writeFlag = [];
	if isempty( writeFlag )
		writeFlag = exist( pngOut, 'file' ) ~= 2;		
		if ~writeFlag
			writeFlag(:) = strcmp( questdlg( 'png exists. overwrite?', mfilename, 'no', 'yes', 'no' ), 'yes' );
		end
	end
	if writeFlag
		% print( hFig, ... ) & saveas( hFig, ... ) don't preserve pixel dimensions
		figPos = get( hFig, 'Position' );		% is this going to work on BWH cluster when scheduled w/ no graphical interface?
		img = getframe( hFig );
		img = imresize( img.cdata, figPos(4) / size( img.cdata, 1 ), 'bicubic' );		% scale by height
		imwrite( img, pngOut, 'png' )
		fprintf( 'wrote %s\n', pngOut )
	end
	
	return

	function yRange = yRangeFcn( Y )
		% extrema
		yRange = [ min( Y, [], 'all' ), max( Y, [], 'all' ) ];
		% make symmetric about zero
		yRange(2) = max( -yRange(1), yRange(2) );
		yRange(1) = -yRange(2);
		% pad a little?
		yRange(:) = yRange + [ -1, 1 ] * diff( yRange ) * 0.125;
	end
	
	
	

%{

	% relics of interactive peak picking, won't work as is!

	function sliceClickCB( varargin )
		if varargin{2}.Button ~= 3
			return
		end
		g = ginput( 1 );
		if g(1) <= tWinPlot(1) || g(1) >= tWinPlot(2)
			return
		end
		% what peak are you modifying? 1=standard, 2=target, 3=novel
		iiPk = get( varargin{1}, 'UserData' );
		% move the line.  note: hTime(iiPk) is varargin{1}
		[ ~, jPk(iiPk) ] = min( abs( EEG.times(jTime) - g(1) ) );
		set( hTime(iiPk), 'XData', EEG.times(jPk([ iiPk, iiPk ])+jT0) )
		getTopoMaps
		% note: topoplot( ..., 'noplot', 'on' ) was a complete fail.  closes figure.  put a copy in my modification folder.
		switch iiPk
			case 1
			case 2
				[ ~, cdata ] = topoplot( tmStandardT, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(1), 'CData', cdata )
				set( ylabT, 'String', sprintf( '%0.0f ms', EEG.times(jPk(iiPk)+jT0) ) )
				
				[ ~, cdata ] = topoplot( tmTarget, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(2), 'CData', cdata )
				
				[ ~, cdata ] = topoplot( tmTarget - tmStandardT, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(3), 'CData', cdata )
			case 3
				iTopo = 3*doTarget;
				[ ~, cdata ] = topoplot( tmStandardN, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(iTopo+1), 'CData', cdata )
				set( ylabN, 'String', sprintf( '%0.0f ms', EEG.times(jPk(iiPk)+jT0) ) )
				
				[ ~, cdata ] = topoplot( tmNovel, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(iTopo+2), 'CData', cdata )
				
				[ ~, cdata ] = topoplot( tmNovel - tmStandardN, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(iTopo+3), 'CData', cdata )
		end
% 		title( hAx(1), sprintf( '%s \\color[rgb]{0,0.75,0}%0.0f ms', epochName, EEG.times(jPk) ) )
% 		xlabel( hAx(nSet), sprintf( '%0.0f ms', EEG.times(jPk+jT0) ) )
% 		set( xLab, 'String', sprintf( '%0.0f ms', EEG.times(jPk+jT0) ) )

	end

	function getTopoMaps
% 		iiPk = find(~isnan(jPk),1,'first');
		if isnan( jPk(2) )
			tmStandardT(:) = nan;
			tmTarget(:)    = nan;
		elseif tWidthTopo == 0
			tmStandardT(:) = YmStandard(:,jPk(2));
			tmTarget(:)    =   YmTarget(:,jPk(2));
		else
% 			jt   = jPk(iiPk) + jT0;
% 			jAvg = EEG.times(jTime) >= EEG.times(jt) - tWidthTopo/2 & EEG.times(jTime) <= EEG.times(jt) + tWidthTopo/2;
% 			tmStandard   = mean( YmStandard(:,jAvg), 2, 'includenan' );
			jt   = jPk(2) + jT0;
			jAvg = EEG.times(jTime) >= EEG.times(jt) - tWidthTopo/2 & EEG.times(jTime) <= EEG.times(jt) + tWidthTopo/2;
			tmStandardT(:) = mean( YmStandard(:,jAvg), 2, 'includenan' );
			tmTarget(:)    = mean(   YmTarget(:,jAvg), 2, 'includenan' );
		end
		if isnan( jPk(3) )
			tmStandardN(:) = nan;
			tmNovel(:)     = nan;
		elseif tWidthTopo == 0
			tmStandardN(:) = YmStandard(:,jPk(3));
			tmNovel(:)     =    YmNovel(:,jPk(3));
		else
			jt(:)   = jPk(3) + jT0;
			jAvg(:) = EEG.times(jTime) >= EEG.times(jt) - tWidthTopo/2 & EEG.times(jTime) <= EEG.times(jt) + tWidthTopo/2;
			tmStandardN(:) = mean( YmStandard(:,jAvg), 2, 'includenan' );
			tmNovel(:)     = mean(    YmNovel(:,jAvg), 2, 'includenan' );
		end
	end


%}


%%
%{
	if isunix
% 		AMPSCZdir = '/data/predict/kcho/flow_test';					% don't work here, outputs will get deleted.  aws rsync to NDA s2
		AMPSCZdir = '/data/predict/kcho/flow_test/spero';			% kevin got rid of group folder & only gave me pronet?	
	else %if ispc
		AMPSCZdir = 'C:\Users\donqu\Documents\NCIRE\AMPSCZ';
	end
	
	proc = AMPSCZ_EEG_findProcSessions;
	
	taskName = { 'MMN', 'VOD', 'AOD' };
	for iProc = 4:size(proc,1)
		close all
		matDir = fullfile( AMPSCZdir, proc{iProc,1}(1:end-2), 'PHOENIX', 'PROTECTED', proc{iProc,1}, 'processed', proc{iProc,2}, 'eeg', [ 'ses-', proc{iProc,3} ], 'mat' );
		for iTask = 1:numel( taskName )
			AMPSCZ_EEG_ERPplot( fullfile( matDir, [ proc{iProc,2}, '_', proc{iProc,3}, '_', taskName{iTask}, '_[0.1,50].mat' ] ) )
		end
	end
%}
%%
	
end


