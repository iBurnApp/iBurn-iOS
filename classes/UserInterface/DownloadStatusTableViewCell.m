//
//  DownloadStatusTableViewCell.m
//  TrailTracker
//
//  Created by Anna Johnson on 6/7/13.
//
//

#import "DownloadStatusTableViewCell.h"

@implementation DownloadStatusTableViewCell


- (UILabel*)defaultLabel {
  UILabel *label = [[UILabel alloc]init];
  label.backgroundColor = [UIColor clearColor];
  [self.contentView addSubview:label];
  return label;
}


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
      self.titleLabel = [self defaultLabel];
     
      self.slugLabel = [self defaultLabel];
      self.slugLabel.textColor = [UIColor grayColor];
      
      self.speedLabel = [self defaultLabel];
      self.speedLabel.textColor = [UIColor grayColor];
      self.speedLabel.textAlignment = UITextAlignmentRight;
      
      self.sizeLabel = [self defaultLabel];
      self.sizeLabel.textAlignment = UITextAlignmentRight;
      
      self.progressView = [[UIProgressView alloc]init];
      self.progressView.progress = 0;
      [self.contentView addSubview:self.progressView];
      
      self.icon = [[UIImageView alloc]init];
      [self.contentView addSubview:self.icon];
      self.overlayIcon = [[UIImageView alloc]init];
      [self.icon addSubview:self.overlayIcon];
      
      
    }
    return self;
}

- (void) refreshDownloadStatus {
  [self updateDownloadProgress:nil];
}

- (void) layoutSubviews {
  [super layoutSubviews];
  
  int iconSize = 25;
  int labelHeight = 22;
  int padding = 5;
  
  self.icon.frame = CGRectMake(5, 5, iconSize, iconSize);
  self.icon.image = [UIImage imageNamed:@"textured-icon-box.png"];
  self.overlayIcon.frame = CGRectMake(3, 3, iconSize-6, iconSize-6);
  
  self.titleLabel.frame = CGRectMake(padding + padding + iconSize,
                                     padding,
                                     self.contentView.frame.size.width-80-iconSize,
                                     22);
  self.slugLabel.frame = CGRectMake(padding,
                                    padding + padding + labelHeight,
                                    self.contentView.frame.size.width - padding - padding,
                                    labelHeight);
  self.progressView.frame = CGRectMake(padding,
                                       self.slugLabel.frame.origin.y + labelHeight + padding,
                                       self.contentView.frame.size.width - padding - padding - 100,
                                       labelHeight);
  self.sizeLabel.frame = CGRectMake(self.titleLabel.frame.size.width + padding,
                                     padding,
                                     self.contentView.frame.size.width-self.titleLabel.frame.size.width - padding - padding,
                                     22);
  self.speedLabel.frame = CGRectMake(self.progressView.frame.size.width + padding + padding,
                                       self.slugLabel.frame.origin.y + labelHeight - padding,
                                       self.contentView.frame.size.width - self.progressView.frame.size.width - padding - padding - padding,
                                       labelHeight);

}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
  [super setSelected:selected animated:animated];
}

- (void)dealloc {

}

- (void)prepareForReuse {

  self.titleLabel.text = nil;
  self.slugLabel.text = nil;
  self.speedLabel.text = nil;
  self.icon.image = nil;
  self.progressView.progress = 0;
  self.downloadStatus = nil;
  
  [refreshTimer invalidate];
  refreshTimer = nil;
}


- (void) setDoneLabels {
  self.speedLabel.text = @"Success";
  self.progressView.progress = 1;
}


- (void) setDownloadStatus:(DownloadStatus *)ds {
  _downloadStatus = ds;

  self.titleLabel.text = self.downloadStatus.name;
  self.slugLabel.text = self.downloadStatus.slug;
  if (self.downloadStatus.totalDownloadSize == 0) {
    self.sizeLabel.text = nil;
  }  else {
    //self.sizeLabel.text = [UnitUtil getFileSize:self.downloadStatus.totalDownloadSize/1000];
  }
  self.overlayIcon.image = self.downloadStatus.icon;
  
  [self.progressView setProgress:0];
  
  [self updateDownloadProgress:nil];
  
  if (self.downloadStatus.progress == 1
      || [self.downloadStatus.msg isEqualToString:@"Success"]) {
    [self setDoneLabels];
    return;
  }
  
  [self updateSpeedLabel];
  
  refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                  target:self
                                                selector:@selector(refreshDownloadStatus)
                                                userInfo:nil
                                                 repeats:YES];
  
  
}


- (void) updateSpeedLabel {
  if (self.downloadStatus.currentBandwidth == 0 || !self.downloadStatus.downloading) {
    self.speedLabel.text = self.downloadStatus.msg;
  } else if (self.downloadStatus.currentBandwidth/8 >= 1000) {
    self.speedLabel.text = [NSString stringWithFormat:@"%.1f MB/s", self.downloadStatus.currentBandwidth/8/1000];
  } else {
    self.speedLabel.text = [NSString stringWithFormat:@"%.1f kB/s", self.downloadStatus.currentBandwidth/8];
  }
}


- (void) updateDownloadProgress:(NSNotification*)notification {
  if (self.downloadStatus.progress == 1
      || [self.downloadStatus.msg isEqualToString:@"Success"]) {
    [self setDoneLabels];
    return;
  }
  [self updateSpeedLabel];
  [self.progressView setProgress:self.downloadStatus.progress];
  
  if (self.downloadStatus.totalDownloadSize == 0) {
    self.sizeLabel.text = nil;
  }  else {
    //self.sizeLabel.text = [UnitUtil getFileSize:self.downloadStatus.totalDownloadSize/1000];
  }
}



@end
