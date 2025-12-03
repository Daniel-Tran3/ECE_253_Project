
import torch
import torch.nn as nn
import math
from models.quant_layer import *



cfg = {
    'VGG11': [64, 'M', 128, 'M', 256, 256, 'M', 512, 512, 'M', 512, 512, 'M'],
    'VGG13': [64, 64, 'M', 128, 128, 'M', 256, 256, 'M', 512, 512, 'M', 512, 512, 'M'],
    'VGG16_quant': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 512, 512, 512, 'M', 512, 512, 512, 'M'],
    'final_VGG16_quant': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 8, 'S', 512, 'M', 512, 512, 512, 'M'],
    'final_P2_VGG16_quant': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 16, 'S2', 512, 'M', 512, 512, 512, 'M'],
    'final_P3_VGG16_quant': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 8, 'S_coupled', 'S_coupled', 8, 'M', 512, 512, 512, 'M'],
    'final_16x16_quant': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 16, 'S16', 512, 'M', 512, 512, 512, 'M'],
    'final_16x8_quant': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 16, 'S16x8', 512, 'M', 512, 512, 512, 'M'],
    'final_feed_quant': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 8, 'S_feed', 'S_feed', 8, 'M', 512, 512, 512, 'M'],
    'VGG16': ['F', 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 512, 512, 512, 'M', 512, 512, 512, 'M'],
    'VGG19': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 256, 'M', 512, 512, 512, 512, 'M', 512, 512, 512, 512, 'M'],
}

class LSBs(nn.Module):
    def __init__(self, shift=0):
        super(LSBs, self).__init__()
        self.shift = shift

    def forward(self, x):
        #print(x)
        out = torch.remainder(torch.floor(torch.mul(x, 0.5**self.shift)), 16)
        return out

class VGG_quant(nn.Module):
    def __init__(self, vgg_name, act_bits=4, w_bits=4):
        super(VGG_quant, self).__init__()
        self.features = self._make_layers(cfg[vgg_name], act_bits, w_bits)
        self.classifier = nn.Linear(512, 10)
        self.act_bits = act_bits
        self.w_bits = w_bits

    def forward(self, x):
        out = self.features(x)
        out = out.view(out.size(0), -1)
        out = self.classifier(out)
        return out

    def _make_layers(self, cfg, act_bits=4, w_bits=4):
        layers = []
        in_channels = 3
        for x in cfg:
            if x == 'M':
                layers += [nn.MaxPool2d(kernel_size=2, stride=2)]
            elif x == 'F':  # This is for the 1st layer
                layers += [nn.Conv2d(in_channels, 64, kernel_size=3, padding=1, bias=False),
                           nn.BatchNorm2d(64),
                           nn.ReLU(inplace=True)]
                in_channels = 64
            elif x == 'S':
                #layers += [QuantConv2d(in_channels, 8, kernel_size=3, padding=1, act_bits=act_bits, w_bits=w_bits),
                 #          nn.ReLU(inplace=True)]
                layers += [QuantConv2d(in_channels, 8, kernel_size=3, padding=1, act_bits=act_bits, w_bits=w_bits),
                           nn.ReLU(inplace=True)]
                in_channels = 8
            elif x == 'S2':
                layers += [QuantConv2d(in_channels, 16, kernel_size=3, padding=1, act_bits=act_bits, w_bits=w_bits),
                           nn.ReLU(inplace=True)]
                in_channels = 16
            elif x == 'S16':
                layers += [QuantConv2d(in_channels, 16, kernel_size=3, padding=1, act_bits=act_bits, w_bits=w_bits),
                           nn.ReLU(inplace=True)]
                in_channels = 16
            elif x == 'S16x8':
                layers += [QuantConv2d(in_channels, 8, kernel_size=3, padding=1, act_bits=act_bits, w_bits=w_bits),
                           nn.ReLU(inplace=True)]
                in_channels = 8
            elif x == 'S_coupled':
                #layers += [QuantConv2d(in_channels, 8, kernel_size=3, padding=1, act_bits=act_bits, w_bits=w_bits),
                 #          nn.ReLU(inplace=True)]
                layers += [QuantConv2d(in_channels, 8, kernel_size=3, padding=1, act_bits=act_bits, w_bits=w_bits),
                           nn.ReLU(inplace=True)]
                in_channels = 8
            elif x == 'S_feed':
                #layers += [QuantConv2d(in_channels, 8, kernel_size=3, padding=1, act_bits=act_bits, w_bits=w_bits),
                 #          nn.ReLU(inplace=True)]
                layers += [QuantConv2d4b(in_channels, 8, kernel_size=3, padding=1, act_bits=act_bits, w_bits=w_bits),
                           nn.ReLU(inplace=True),
                           LSBs(shift=0)]
                in_channels = 8
            else:
                layers += [QuantConv2d(in_channels, x, kernel_size=3, padding=1, act_bits=act_bits, w_bits=w_bits),
                           nn.BatchNorm2d(x),
                           nn.ReLU(inplace=True)]
                in_channels = x
        if x != 'S_feed':
            layers += [nn.AvgPool2d(kernel_size=1, stride=1)]
        return nn.Sequential(*layers)

    def show_params(self):
        for m in self.modules():
            if isinstance(m, QuantConv2d):
                m.show_params()
    

def VGG16_quant(**kwargs):
    model = VGG_quant(vgg_name = 'VGG16_quant', **kwargs)
    return model

def final_VGG16_quant(**kwargs):
    model = VGG_quant(vgg_name = 'final_VGG16_quant', act_bits=4, w_bits=4, **kwargs)
    return model

def final_16x16_quant(**kwargs):
    model = VGG_quant(vgg_name = 'final_16x16_quant', act_bits=4, w_bits=4, **kwargs)
    return model

def final_16x8_quant(**kwargs):
    model = VGG_quant(vgg_name = 'final_16x8_quant', act_bits=4, w_bits=4, **kwargs)
    return model

def final_P2_VGG16_quant(**kwargs):
    model = VGG_quant(vgg_name = 'final_P2_VGG16_quant', act_bits=2, w_bits=4, **kwargs)
    return model

def final_P3_VGG16_quant(**kwargs):
    model = VGG_quant(vgg_name = 'final_P3_VGG16_quant', act_bits=4, w_bits=4, **kwargs)
    return model
    
def final_feed_quant(**kwargs):
    model = VGG_quant(vgg_name = 'final_feed_quant', act_bits=4, w_bits=4, **kwargs)
    return model

